################################################################################
#
# retroarch-assets
#
# Ozone/XMB 메뉴에 필요한 UI 텍스처·아이콘 패키지
# retroarch.mk의 media/ 복사는 폰트만 포함하므로 별도 패키지로 설치
#
################################################################################

RETROARCH_ASSETS_VERSION = cd17f64cff4eaff187a0702d17520ccb9a760fe3
RETROARCH_ASSETS_SITE = https://github.com/libretro/retroarch-assets
RETROARCH_ASSETS_SITE_METHOD = git
RETROARCH_ASSETS_LICENSE = CC-BY-4.0

define RETROARCH_ASSETS_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/opt/retropangui/share/retroarch
	# ozone: UI 텍스처·시스템 아이콘 (png/), 폰트 (fonts/)
	cp -r $(@D)/ozone $(TARGET_DIR)/opt/retropangui/share/retroarch/
	# xmb: XMB 메뉴 테마 리소스 (빌드 옵션 --enable-xmb 대응)
	cp -r $(@D)/xmb $(TARGET_DIR)/opt/retropangui/share/retroarch/
endef

$(eval $(generic-package))
