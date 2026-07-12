################################################################################
#
# odroid-drm-fbset
#
################################################################################

ODROID_DRM_FBSET_VERSION      = 1.0.0
ODROID_DRM_FBSET_SITE         = $(BR2_EXTERNAL_C5_PANGUI_PATH)/package/odroid-drm-fbset/src
ODROID_DRM_FBSET_SITE_METHOD  = local
ODROID_DRM_FBSET_LICENSE      = MIT
ODROID_DRM_FBSET_DEPENDENCIES = libdrm host-pkgconf

define ODROID_DRM_FBSET_BUILD_CMDS
	$(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS) `$(HOST_DIR)/bin/pkg-config --cflags libdrm`" \
		LDFLAGS="$(TARGET_LDFLAGS) `$(HOST_DIR)/bin/pkg-config --libs libdrm`"
endef

# 원본 바이너리가 있던 /usr/sbin/odroid-drm-fbset 경로 그대로 설치 -
# S60display/S99emulationstation/terminal.py 등 호출부 수정 불필요.
define ODROID_DRM_FBSET_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 $(@D)/odroid-drm-fbset \
		$(TARGET_DIR)/usr/sbin/odroid-drm-fbset
endef

$(eval $(generic-package))
