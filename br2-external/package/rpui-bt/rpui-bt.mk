################################################################################
#
# rpui-bt
#
################################################################################

RPUI_BT_VERSION     = 1.0.0
RPUI_BT_SITE        = $(BR2_EXTERNAL_C5_PANGUI_PATH)/package/rpui-bt/src
RPUI_BT_SITE_METHOD = local
RPUI_BT_LICENSE     = MIT
RPUI_BT_DEPENDENCIES = bluez5_utils

define RPUI_BT_BUILD_CMDS
	$(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS)" \
		LDFLAGS="$(TARGET_LDFLAGS)"
endef

define RPUI_BT_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 $(@D)/rpui-bt \
		$(TARGET_DIR)/usr/bin/rpui-bt
endef

$(eval $(generic-package))
