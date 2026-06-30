################################################################################
#
# storage-mgr
#
################################################################################

STORAGE_MGR_VERSION     = 1.0.0
STORAGE_MGR_SITE        = $(BR2_EXTERNAL_C5_PANGUI_PATH)/package/storage-mgr/src
STORAGE_MGR_SITE_METHOD = local
STORAGE_MGR_LICENSE     = MIT

define STORAGE_MGR_BUILD_CMDS
	$(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS)" \
		LDFLAGS="$(TARGET_LDFLAGS)"
endef

define STORAGE_MGR_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 $(@D)/storage-mgr \
		$(TARGET_DIR)/usr/bin/storage-mgr
endef

$(eval $(generic-package))
