################################################################################
#
# rpui-bt
#
################################################################################

RPUI_BT_VERSION     = 1.0.0
RPUI_BT_SITE        = $(BR2_EXTERNAL_C5_PANGUI_PATH)/package/rpui-bt/src
RPUI_BT_SITE_METHOD = local
RPUI_BT_LICENSE     = MIT
RPUI_BT_DEPENDENCIES = bluez5_utils libglib2

define RPUI_BT_BUILD_CMDS
	$(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS)" \
		LDFLAGS="$(TARGET_LDFLAGS)" \
		PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
		PKG_CONFIG_LIBDIR="$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/usr/share/pkgconfig" \
		PKG_CONFIG_SYSROOT_DIR="$(STAGING_DIR)"
endef

define RPUI_BT_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 $(@D)/rpui-bt \
		$(TARGET_DIR)/usr/bin/rpui-bt
endef

$(eval $(generic-package))
