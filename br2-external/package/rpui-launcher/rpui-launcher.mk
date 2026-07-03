################################################################################
#
# rpui-launcher
#
################################################################################

RPUI_LAUNCHER_VERSION = 1.0
RPUI_LAUNCHER_SOURCE =
RPUI_LAUNCHER_LICENSE = MIT

RPUI_LAUNCHER_DEPENDENCIES = python3

define RPUI_LAUNCHER_INSTALL_TARGET_CMDS
	install -D -m 0755 $(BR2_EXTERNAL_C5_PANGUI_PATH)/../board/odroidc5/rpui-launcher.py \
		$(TARGET_DIR)/usr/bin/rpui-launcher
endef

$(eval $(generic-package))
