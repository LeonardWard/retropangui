################################################################################
#
# rpui-wifi
#
################################################################################

RPUI_WIFI_VERSION     = 1.0.0
RPUI_WIFI_SITE        = $(BR2_EXTERNAL_C5_PANGUI_PATH)/package/rpui-wifi/src
RPUI_WIFI_SITE_METHOD = local
RPUI_WIFI_LICENSE     = MIT
RPUI_WIFI_DEPENDENCIES = wpa_supplicant

define RPUI_WIFI_BUILD_CMDS
	$(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS)" \
		LDFLAGS="$(TARGET_LDFLAGS)"
endef

define RPUI_WIFI_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 $(@D)/rpui-wifi \
		$(TARGET_DIR)/usr/bin/rpui-wifi
endef

$(eval $(generic-package))
