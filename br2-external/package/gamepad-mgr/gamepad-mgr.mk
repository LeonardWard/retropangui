################################################################################
#
# gamepad-mgr
#
################################################################################

GAMEPAD_MGR_VERSION       = 1.0.0
GAMEPAD_MGR_SITE          = $(BR2_EXTERNAL_C5_PANGUI_PATH)/package/gamepad-mgr/src
GAMEPAD_MGR_SITE_METHOD   = local
GAMEPAD_MGR_DEPENDENCIES  = sdl2
GAMEPAD_MGR_LICENSE       = MIT

define GAMEPAD_MGR_BUILD_CMDS
	$(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS) -I$(STAGING_DIR)/usr/include/SDL2 -D_REENTRANT" \
		LDFLAGS="$(TARGET_LDFLAGS) -L$(STAGING_DIR)/usr/lib -lSDL2 -lm" \
		libgamepad.a gamepad-test gamepad-daemon
endef

define GAMEPAD_MGR_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 $(@D)/gamepad-test \
		$(TARGET_DIR)/usr/bin/gamepad-test
	$(INSTALL) -D -m 755 $(@D)/gamepad-daemon \
		$(TARGET_DIR)/usr/bin/gamepad-daemon
	$(INSTALL) -D -m 644 $(@D)/libgamepad.a \
		$(TARGET_DIR)/usr/lib/libgamepad.a
	$(INSTALL) -D -m 644 $(@D)/gamepad.h \
		$(TARGET_DIR)/usr/include/gamepad.h
endef

$(eval $(generic-package))
