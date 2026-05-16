/* Mali EGL wrapper - SONAME=libEGL.so.1
 *
 * 1. Provides eglGetPlatformDisplayEXT (EXT version missing from libMali.so)
 *    by delegating to Mali's eglGetPlatformDisplay (EGL 1.5).
 *
 * 2. Intercepts eglQueryString(EGL_NO_DISPLAY, EGL_EXTENSIONS) to inject
 *    "EGL_MESA_platform_gbm" alongside "EGL_KHR_platform_gbm".
 *    Kodi GBM (WinSystemGbmGLESContext) checks for EGL_MESA_platform_gbm
 *    to enable the eglGetPlatformDisplayEXT path; Mali only advertises
 *    EGL_KHR_platform_gbm (same enum value 0x31D7, different string).
 *
 * 3. Intercepts eglGetConfigAttrib(EGL_NATIVE_VISUAL_ID) to return
 *    GBM_FORMAT_XRGB8888 when Mali returns ABGR8888.
 *    Mali Valhall GBM configs don't set EGL_NATIVE_VISUAL_ID; Kodi's
 *    CEGLContextUtils::ChooseConfig iterates formats (AR30, XR30, AR24,
 *    XR24) and matches against this attribute to pick a GBM pixel format.
 *    Without substitution every attempt fails and Kodi can't init its
 *    windowing system.
 *
 * 4. Intercepts drmModeAddFB2WithModifiers / drmModeAddFB2 to substitute
 *    XRGB8888 → ABGR8888 when registering GBM BOs as DRM framebuffers.
 *    Mali GBM reports XRGB8888 from gbm_bo_get_format even though the EGL
 *    surface is ABGR8888; the GPU stores pixels as [R,G,B,A] (ABGR layout).
 *    DRM XRGB8888 interprets byte0 as B, causing a red/blue channel swap.
 *    Substituting XRGB8888→ABGR8888 tells the Amlogic OSD byte0=R → correct.
 *    Loaded via LD_PRELOAD so these symbols take precedence over libdrm.so.
 */
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <dlfcn.h>

/* DRM format fourcc */
#define DRM_FORMAT_ABGR8888  0x34324241U
#define DRM_FORMAT_XRGB8888  0x34325258U

typedef unsigned int EGLenum;
typedef unsigned int EGLBoolean;
typedef void *EGLDisplay;
typedef void *EGLConfig;
typedef int EGLint;
typedef intptr_t EGLAttrib;

#define EGL_TRUE              1
#define EGL_FALSE             0
#define EGL_NO_DISPLAY        ((EGLDisplay)0)
#define EGL_EXTENSIONS        0x3055
#define EGL_NATIVE_VISUAL_ID  0x302E
/* fourcc_code('A','B','2','4') — Mali Valhall GBM GLES2 config actual format */
#define GBM_FORMAT_ABGR8888   0x34324241
/* fourcc_code('X','R','2','4') — no-alpha RGBX format */
#define GBM_FORMAT_XRGB8888   0x34325258
/* fourcc_code('A','R','2','4') — format SDL2 and Kodi request */
#define GBM_FORMAT_ARGB8888   0x34325241

extern EGLDisplay eglGetPlatformDisplay(EGLenum platform, void *native_display,
                                         const EGLAttrib *attrib_list);

__attribute__((visibility("default")))
EGLDisplay eglGetPlatformDisplayEXT(EGLenum platform, void *native_display,
                                     const EGLint *attrib_list) {
    return eglGetPlatformDisplay(platform, native_display, (const EGLAttrib *)attrib_list);
}

__attribute__((visibility("default")))
EGLDisplay _eglGetPlatformDisplayEXT(EGLenum platform, void *native_display,
                                      const EGLint *attrib_list) {
    return eglGetPlatformDisplay(platform, native_display, (const EGLAttrib *)attrib_list);
}

/* Buffer large enough for the extensions string + our addition */
static char _ext_buf[8192];
static char _disp_ext_buf[8192];

/* Remove a token from a space-separated string, writing result to dst (size dstsz).
 * Returns dst. */
static char *remove_ext_token(const char *src, const char *token, char *dst, size_t dstsz) {
    size_t toklen = strlen(token);
    size_t pos = 0;
    const char *p = src;
    dst[0] = '\0';
    while (*p) {
        const char *end = p;
        while (*end && *end != ' ') end++;
        size_t len = (size_t)(end - p);
        if (!(len == toklen && strncmp(p, token, len) == 0)) {
            if (pos > 0 && pos + 1 < dstsz) dst[pos++] = ' ';
            if (pos + len < dstsz) { memcpy(dst + pos, p, len); pos += len; }
        }
        p = (*end == ' ') ? end + 1 : end;
    }
    dst[pos] = '\0';
    return dst;
}

/* Intercept eglQueryString:
 * - Client extensions (EGL_NO_DISPLAY): inject EGL_MESA_platform_gbm so Kodi
 *   uses eglGetPlatformDisplayEXT (which we provide).
 * - Display extensions: remove EGL_ANDROID_native_fence_sync to disable Kodi's
 *   fence-based buffer synchronization, which conflicts with Mali r44p0's GBM
 *   buffer management and causes eglSwapBuffers EGL_BAD_ALLOC.
 *
 * RTLD_NEXT cannot find libMali.so (DT_NEEDED dep loads before us in link map).
 * Use dlopen(RTLD_NOLOAD) to get an explicit handle instead. */
__attribute__((visibility("default")))
const char *eglQueryString(EGLDisplay dpy, EGLint name) {
    typedef const char *(*pfn_t)(EGLDisplay, EGLint);
    static pfn_t real_fn = NULL;
    if (!real_fn) {
        void *h = dlopen("libMali.so", RTLD_LAZY | RTLD_NOLOAD);
        if (!h) h = dlopen("libMali.so", RTLD_LAZY | RTLD_GLOBAL);
        if (h) real_fn = (pfn_t)dlsym(h, "eglQueryString");
    }
    if (!real_fn) return NULL;
    const char *result = real_fn(dpy, name);

    if (name == EGL_EXTENSIONS && result) {
        if (dpy == EGL_NO_DISPLAY && !strstr(result, "EGL_MESA_platform_gbm")) {
            snprintf(_ext_buf, sizeof(_ext_buf), "%s EGL_MESA_platform_gbm", result);
            return _ext_buf;
        }
        if (dpy != EGL_NO_DISPLAY && strstr(result, "EGL_ANDROID_native_fence_sync")) {
            remove_ext_token(result, "EGL_ANDROID_native_fence_sync",
                             _disp_ext_buf, sizeof(_disp_ext_buf));
            return _disp_ext_buf;
        }
    }
    return result;
}

/* Intercept eglChooseConfig to force EGL_ALPHA_SIZE=8 when SDL2 (or any caller)
 * passes alpha_size=0.  Mali Valhall only exposes ABGR8888 (alpha) configs for
 * GBM; without alpha=8 it returns XRGB8888 configs which then mismatch the
 * ABGR8888 GBM surface and cause eglCreateWindowSurface EGL_BAD_MATCH. */
__attribute__((visibility("default")))
EGLBoolean eglChooseConfig(EGLDisplay dpy, const EGLint *attrib_list,
                            EGLConfig *configs, EGLint config_size,
                            EGLint *num_config) {
    typedef EGLBoolean (*pfn_t)(EGLDisplay, const EGLint *, EGLConfig *,
                                EGLint, EGLint *);
    static pfn_t real_fn = NULL;
    if (!real_fn) {
        void *h = dlopen("libMali.so", RTLD_LAZY | RTLD_NOLOAD);
        if (!h) h = dlopen("libMali.so", RTLD_LAZY | RTLD_GLOBAL);
        if (h) real_fn = (pfn_t)dlsym(h, "eglChooseConfig");
    }
    if (!real_fn) return EGL_FALSE;
#define _EGL_ALPHA_SIZE 0x3021
#define _EGL_NONE       0x3038
#define _MAX_ATTRIBS    128
    if (attrib_list) {
        EGLint modified[_MAX_ATTRIBS];
        int n = 0;
        const EGLint *p = attrib_list;
        while (n < _MAX_ATTRIBS - 1 && *p != _EGL_NONE) {
            modified[n++] = *p;
            if (*p == _EGL_ALPHA_SIZE) {
                p++;
                modified[n++] = (*p == 0) ? 8 : *p;
                p++;
            } else {
                p++;
                modified[n++] = *p++;
            }
        }
        modified[n] = _EGL_NONE;
        return real_fn(dpy, modified, configs, config_size, num_config);
    }
    return real_fn(dpy, attrib_list, configs, config_size, num_config);
}

/* Intercept eglGetConfigAttrib to substitute EGL_NATIVE_VISUAL_ID=ABGR8888 with
 * GBM_FORMAT_ARGB8888.  Mali Valhall GBM configs report ABGR8888 internally.
 * SDL2 sets required_visual_id=ARGB8888 (GBM_FORMAT_ARGB8888=0x34325241).
 * Kodi iterates AR30→XR30→AR24→XR24; AR24=ARGB8888 matches first.
 * Reporting ARGB8888 lets both callers find a matching config. */
__attribute__((visibility("default")))
EGLBoolean eglGetConfigAttrib(EGLDisplay dpy, EGLConfig config,
                               EGLint attribute, EGLint *value) {
    typedef EGLBoolean (*pfn_t)(EGLDisplay, EGLConfig, EGLint, EGLint *);
    static pfn_t real_fn = NULL;
    if (!real_fn) {
        void *h = dlopen("libMali.so", RTLD_LAZY | RTLD_NOLOAD);
        if (!h) h = dlopen("libMali.so", RTLD_LAZY | RTLD_GLOBAL);
        if (h) real_fn = (pfn_t)dlsym(h, "eglGetConfigAttrib");
    }
    if (!real_fn) return EGL_FALSE;

    EGLBoolean ret = real_fn(dpy, config, attribute, value);
    if (ret == EGL_TRUE && attribute == EGL_NATIVE_VISUAL_ID && value &&
        *value == (EGLint)GBM_FORMAT_ABGR8888)
        *value = (EGLint)GBM_FORMAT_ARGB8888;
    return ret;
}

/* Intercept DRM framebuffer registration to fix Mali Valhall colour channel swap.
 *
 * Mali Valhall stores pixels in BGRA byte order for its "ABGR8888" EGL surface
 * (memory: [B][G][R][A]).  DRM_FORMAT_ABGR8888 tells the display engine that
 * byte0 = R, which swaps R and B on screen.  DRM_FORMAT_XRGB8888 tells the
 * display engine that byte0 = B, which matches the actual memory layout and
 * produces correct colours.  Loaded via LD_PRELOAD so these symbols shadow
 * libdrm.so for all callers in the process. */
__attribute__((visibility("default")))
int drmModeAddFB2WithModifiers(int fd,
                                uint32_t width, uint32_t height,
                                uint32_t pixel_format,
                                const uint32_t handles[4],
                                const uint32_t pitches[4],
                                const uint32_t offsets[4],
                                const uint64_t modifiers[4],
                                uint32_t *buf_id, uint32_t flags) {
    typedef int (*pfn_t)(int, uint32_t, uint32_t, uint32_t,
                         const uint32_t *, const uint32_t *, const uint32_t *,
                         const uint64_t *, uint32_t *, uint32_t);
    static pfn_t real_fn = NULL;
    if (!real_fn) real_fn = (pfn_t)dlsym(RTLD_NEXT, "drmModeAddFB2WithModifiers");
    if (!real_fn) return -1;
    /* Mali GBM reports XRGB8888 from gbm_bo_get_format even though the EGL
     * surface is ABGR8888; the GPU stores pixels as [R,G,B,A] (ABGR layout).
     * DRM XRGB8888 interprets byte0 as B, swapping R↔B on screen.
     * Substituting XRGB8888→ABGR8888 tells the display engine byte0=R → correct. */
    if (pixel_format == DRM_FORMAT_XRGB8888)
        pixel_format = DRM_FORMAT_ABGR8888;
    return real_fn(fd, width, height, pixel_format,
                   handles, pitches, offsets, modifiers, buf_id, flags);
}

__attribute__((visibility("default")))
int drmModeAddFB2(int fd,
                  uint32_t width, uint32_t height,
                  uint32_t pixel_format,
                  const uint32_t handles[4],
                  const uint32_t pitches[4],
                  const uint32_t offsets[4],
                  uint32_t *buf_id, uint32_t flags) {
    typedef int (*pfn_t)(int, uint32_t, uint32_t, uint32_t,
                         const uint32_t *, const uint32_t *, const uint32_t *,
                         uint32_t *, uint32_t);
    static pfn_t real_fn = NULL;
    if (!real_fn) real_fn = (pfn_t)dlsym(RTLD_NEXT, "drmModeAddFB2");
    if (!real_fn) return -1;
    if (pixel_format == DRM_FORMAT_XRGB8888)
        pixel_format = DRM_FORMAT_ABGR8888;
    return real_fn(fd, width, height, pixel_format,
                   handles, pitches, offsets, buf_id, flags);
}
