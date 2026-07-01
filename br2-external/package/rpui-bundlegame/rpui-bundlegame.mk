################################################################################
#
# rpui-bundlegame - 번들 ROM 관리 커맨드
#
################################################################################

RPUI_BUNDLEGAME_VERSION     = 1.0
RPUI_BUNDLEGAME_SITE        = $(BR2_EXTERNAL_C5_PANGUI_PATH)/package/rpui-bundlegame
RPUI_BUNDLEGAME_SITE_METHOD = local
RPUI_BUNDLEGAME_LICENSE     = MIT

define RPUI_BUNDLEGAME_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 $(BR2_EXTERNAL_C5_PANGUI_PATH)/package/rpui-bundlegame/rpui-bundlegame.sh \
		$(TARGET_DIR)/usr/bin/rpui-bundlegame
endef

$(eval $(generic-package))
