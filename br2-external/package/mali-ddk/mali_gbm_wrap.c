/* Mali GBM wrapper - SONAME=libgbm.so.1
 *
 * Intercepts gbm_surface_create and gbm_surface_create_with_modifiers to
 * normalize pixel formats for Mali EGL.
 *
 * Mali Valhall (r44p0) GBM EGL configs have EGL_NATIVE_VISUAL_ID = ABGR8888.
 * Kodi uses XRGB8888 (from the EGL config attrib after our EGL wrapper's
 * ABGR8888→XRGB8888 substitution). eglCreateWindowSurface checks that the
 * GBM surface format matches the EGL config's internal format (ABGR8888).
 * Translating XRGB8888 back to ABGR8888 here ensures the match succeeds.
 *
 * SDL2 KMSDRM hardcodes ARGB8888, which also needs translation to ABGR8888.
 *
 * NOTE: RTLD_NEXT cannot be used here because LD_PRELOAD of libEGL.so.1
 * causes libMali.so to be loaded before libgbm.so.1 in the link map.
 * RTLD_NEXT from inside libgbm.so.1 would look *after* libgbm.so.1 and
 * miss libMali.so entirely, returning NULL.  Use dlopen(RTLD_NOLOAD) to
 * get an explicit handle to libMali.so regardless of load order.
 *
 * For gbm_surface_create_with_modifiers: translate format to ABGR8888 but
 * keep the original modifiers.  The same AFBC modifier flags apply to both
 * XRGB8888 and ABGR8888 (modifiers encode compression scheme, not channel
 * order).  This avoids the LINEAR fallback which caused eglCreateWindowSurface
 * to fail (Mali r44p0 requires AFBC modifiers for the GBM window surface).
 *
 * Also intercepts gbm_surface_has_free_buffers to cap outstanding locked BOs
 * at 2, forcing Kodi to release old BOs every frame. Mali GBM surfaces have a
 * large internal pool so has_free_buffers never returns false on its own,
 * causing BOs to accumulate until EGL runs out of back-buffer slots (EGL_BAD_ALLOC).
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stddef.h>
#include <stdint.h>
#include <stdatomic.h>

#define DRM_FORMAT_ARGB8888  0x34325241U
#define DRM_FORMAT_XRGB8888  0x34325258U
#define DRM_FORMAT_ABGR8888  0x34324241U

#define GBM_BO_USE_SCANOUT   (1u << 0)
#define GBM_BO_USE_RENDERING (1u << 2)

static unsigned int normalize_format(unsigned int format) {
    if (format == DRM_FORMAT_ARGB8888 || format == DRM_FORMAT_XRGB8888)
        return DRM_FORMAT_ABGR8888;
    return format;
}

/* Get a function pointer from libMali.so, bypassing RTLD_NEXT load-order issues. */
static void *mali_sym(const char *name) {
    static void *mali_handle = NULL;
    if (!mali_handle) {
        mali_handle = dlopen("libMali.so", RTLD_LAZY | RTLD_NOLOAD);
        if (!mali_handle)
            mali_handle = dlopen("libMali.so", RTLD_LAZY | RTLD_GLOBAL);
    }
    return mali_handle ? dlsym(mali_handle, name) : NULL;
}

static void *(*real_gbm_surface_create)(void *, unsigned int, unsigned int,
                                          unsigned int, unsigned int);

__attribute__((visibility("default")))
void *gbm_surface_create(void *gbm, unsigned int w, unsigned int h,
                          unsigned int format, unsigned int flags) {
    if (!real_gbm_surface_create)
        real_gbm_surface_create = mali_sym("gbm_surface_create");

    format = normalize_format(format);

    if (real_gbm_surface_create)
        return real_gbm_surface_create(gbm, w, h, format, flags);
    return (void *)0;
}

static void *(*real_gbm_surface_create_with_modifiers)(void *, unsigned int, unsigned int,
                                                         unsigned int, const uint64_t *,
                                                         unsigned int);

/* Translate XRGB/ARGB → ABGR and pass through original modifiers.
 * The same AFBC modifier is valid for ABGR8888; keeping modifiers avoids the
 * LINEAR fallback that caused eglCreateWindowSurface EGL_BAD_MATCH on Mali r44p0. */
__attribute__((visibility("default")))
void *gbm_surface_create_with_modifiers(void *gbm, unsigned int w, unsigned int h,
                                         unsigned int format, const uint64_t *modifiers,
                                         unsigned int count) {
    if (!real_gbm_surface_create_with_modifiers)
        real_gbm_surface_create_with_modifiers = mali_sym("gbm_surface_create_with_modifiers");

    format = normalize_format(format);

    if (real_gbm_surface_create_with_modifiers)
        return real_gbm_surface_create_with_modifiers(gbm, w, h, format, modifiers, count);
    return (void *)0;
}

static void *(*real_gbm_surface_create_with_modifiers2)(void *, unsigned int, unsigned int,
                                                          unsigned int, const uint64_t *,
                                                          unsigned int, unsigned int);

__attribute__((visibility("default")))
void *gbm_surface_create_with_modifiers2(void *gbm, unsigned int w, unsigned int h,
                                          unsigned int format, const uint64_t *modifiers,
                                          unsigned int count, unsigned int flags) {
    if (!real_gbm_surface_create_with_modifiers2)
        real_gbm_surface_create_with_modifiers2 = mali_sym("gbm_surface_create_with_modifiers2");

    format = normalize_format(format);

    if (real_gbm_surface_create_with_modifiers2)
        return real_gbm_surface_create_with_modifiers2(gbm, w, h, format, modifiers, count, flags);
    if (!real_gbm_surface_create_with_modifiers)
        real_gbm_surface_create_with_modifiers = mali_sym("gbm_surface_create_with_modifiers");
    if (real_gbm_surface_create_with_modifiers)
        return real_gbm_surface_create_with_modifiers(gbm, w, h, format, modifiers, count);
    return (void *)0;
}

/* Intercept gbm_bo_get_format to correct Mali Valhall's format reporting.
 * Mali reports GBM_FORMAT_XRGB8888 from gbm_bo_get_format regardless of the
 * actual surface format.  The GPU stores pixels as [R][G][B][A] (ABGR layout);
 * DRM_FORMAT_ABGR8888 (byte0=R) is the correct descriptor.  Without this fix,
 * callers that pass gbm_bo_get_format to drmModeAddFB2 get XRGB8888 (byte0=B),
 * causing a red/blue channel swap on screen. */
__attribute__((visibility("default")))
uint32_t gbm_bo_get_format(void *bo) {
    typedef uint32_t (*pfn_t)(void *);
    static pfn_t real_fn = NULL;
    if (!real_fn) real_fn = mali_sym("gbm_bo_get_format");
    uint32_t fmt = real_fn ? real_fn(bo) : 0;
    /* Mali may return XRGB8888 or an internal non-fourcc code (e.g. 0x1).
     * Any value < 0x01000000 is not a valid DRM fourcc; fall back to ABGR8888. */
    if (fmt == DRM_FORMAT_XRGB8888 || fmt < 0x01000000U)
        fmt = DRM_FORMAT_ABGR8888;
    return fmt;
}

static atomic_int _lock_count = 0;
static atomic_int _release_count = 0;

static void *(*real_gbm_surface_lock_front_buffer)(void *);
static void (*real_gbm_surface_release_buffer)(void *, void *);
static int (*real_gbm_surface_has_free_buffers)(void *);

__attribute__((visibility("default")))
void *gbm_surface_lock_front_buffer(void *surface) {
    if (!real_gbm_surface_lock_front_buffer)
        real_gbm_surface_lock_front_buffer = mali_sym("gbm_surface_lock_front_buffer");
    atomic_fetch_add(&_lock_count, 1);
    return real_gbm_surface_lock_front_buffer ? real_gbm_surface_lock_front_buffer(surface) : (void *)0;
}

__attribute__((visibility("default")))
void gbm_surface_release_buffer(void *surface, void *bo) {
    if (!real_gbm_surface_release_buffer)
        real_gbm_surface_release_buffer = mali_sym("gbm_surface_release_buffer");
    atomic_fetch_add(&_release_count, 1);
    if (real_gbm_surface_release_buffer)
        real_gbm_surface_release_buffer(surface, bo);
}

/* Mali GBM surfaces have a large internal pool so has_free_buffers stays true
 * indefinitely, causing Kodi to never call gbm_surface_release_buffer. This
 * exhausts Mali EGL's back-buffer slots and triggers EGL_BAD_ALLOC after ~14
 * frames. Cap outstanding locked BOs at 2: return 0 (no free buffers) once
 * two or more are outstanding, forcing Kodi to release the oldest each frame. */
__attribute__((visibility("default")))
int gbm_surface_has_free_buffers(void *surface) {
    if (!real_gbm_surface_has_free_buffers)
        real_gbm_surface_has_free_buffers = mali_sym("gbm_surface_has_free_buffers");
    int outstanding = atomic_load(&_lock_count) - atomic_load(&_release_count);
    if (outstanding >= 2)
        return 0;
    return real_gbm_surface_has_free_buffers ? real_gbm_surface_has_free_buffers(surface) : 0;
}
