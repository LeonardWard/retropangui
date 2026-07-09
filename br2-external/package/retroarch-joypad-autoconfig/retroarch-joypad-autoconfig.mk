################################################################################
#
# retroarch-joypad-autoconfig
#
# RetroArch 공식 커뮤니티 컨트롤러 autoconfig DB(udev 서브셋)를 빌드 시
# 가져와서 설치. 이 프로젝트가 실기기에서 직접 검증·수정한 장치는
# board/odroidc5/rootfs-overlay/etc/retroarch/autoconfig/에 그대로 있고
# rootfs-overlay가 패키지 설치보다 나중에 적용되므로 항상 우선함 -
# 그래도 "같은 장치가 다른 파일명으로 중복 등록"되는 걸 막기 위해
# 설치 단계에서 장치명(input_device) 기준으로도 한 번 더 걸러냄.
#
################################################################################

RETROARCH_JOYPAD_AUTOCONFIG_VERSION = 86207989e43a636ee3746d190e73f25c23dc7b81
RETROARCH_JOYPAD_AUTOCONFIG_SITE = https://github.com/libretro/retroarch-joypad-autoconfig
RETROARCH_JOYPAD_AUTOCONFIG_SITE_METHOD = git
RETROARCH_JOYPAD_AUTOCONFIG_LICENSE = MIT

# 이 프로젝트가 이미 실기기에서 직접 검증·수정해서 board/odroidc5/
# rootfs-overlay/etc/retroarch/autoconfig/에 갖고 있는 장치명 - 공식 DB
# 쪽 파일(파일명이 달라도 같은 장치를 가리키면)은 설치하지 않음.
define RETROARCH_JOYPAD_AUTOCONFIG_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/etc/retroarch/autoconfig
	for f in $(@D)/udev/*.cfg; do \
		dev=$$(sed -n 's/^input_device *= *"\(.*\)"/\1/p' "$$f" | head -1); \
		case "$$dev" in \
			"8Bitdo SN30 Pro") continue ;; \
			"8Bitdo SFC30 GamePad") continue ;; \
			"Microsoft X-Box 360 pad") continue ;; \
			"Nintendo Switch Pro Controller") continue ;; \
			"HID 0925:8866") continue ;; \
			"USB GamePad") continue ;; \
			"Sony Interactive Entertainment Wireless Controller") continue ;; \
			"Sony Interactive Entertainment DualSense Wireless Controller") continue ;; \
			"Twin USB Joystick") continue ;; \
			"Xbox 360 Wireless Receiver") continue ;; \
		esac; \
		cp "$$f" "$(TARGET_DIR)/etc/retroarch/autoconfig/"; \
	done
endef

$(eval $(generic-package))
