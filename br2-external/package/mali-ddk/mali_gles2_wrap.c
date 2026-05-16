/* Mali GLES2 wrapper - SONAME=libGLESv2.so.2
 * Provides eglGetPlatformDisplayEXT in GLES2 library scope.
 * SDL2 KMSDRM loads libGLESv2.so.2 with RTLD_LOCAL and then searches
 * its local scope for eglGetPlatformDisplayEXT via dlsym.
 */
#include <stdint.h>

typedef unsigned int EGLenum;
typedef void *EGLDisplay;
typedef int EGLint;
typedef intptr_t EGLAttrib;

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

__attribute__((constructor)) static void __mali_gles2_wrap_init(void) {}
