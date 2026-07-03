################################################################################
#
# rpui-rtl8821cu
#
# 하드커널 WiFi Module 5B/5BK(RTL8821CU) 드라이버.
# Buildroot 기본 rtl8821cu 패키지(morrownr/8821cu-20210916)가 커널 5.15+의
# cfg80211 API 변경(.add_key/.stop_ap/.get_channel 콜백 시그니처, roam_info.bssid
# 제거 등)으로 빌드 실패해서, ODROID 포럼이 하드커널 기기용으로 추천하는
# brektrou/rtl8821CU 소스로 대체 (2026-07-03).
#
################################################################################

RPUI_RTL8821CU_VERSION = 8c2226a74ae718439d56248bd2e44ccf717086d5
RPUI_RTL8821CU_SITE = $(call github,brektrou,rtl8821CU,$(RPUI_RTL8821CU_VERSION))
RPUI_RTL8821CU_LICENSE = GPL-2.0

RPUI_RTL8821CU_USER_EXTRA_CFLAGS = \
	-DCONFIG_$(call qstrip,$(BR2_ENDIAN))_ENDIAN \
	-DCONFIG_IOCTL_CFG80211 \
	-DRTW_USE_CFG80211_STA_EVENT \
	-Wno-error

define RPUI_RTL8821CU_LINUX_CONFIG_FIXUPS
	$(call KCONFIG_ENABLE_OPT,CONFIG_NET)
	$(call KCONFIG_ENABLE_OPT,CONFIG_WIRELESS)
	$(call KCONFIG_ENABLE_OPT,CONFIG_CFG80211)
	$(call KCONFIG_ENABLE_OPT,CONFIG_USB_SUPPORT)
	$(call KCONFIG_ENABLE_OPT,CONFIG_USB)
endef

RPUI_RTL8821CU_MODULE_MAKE_OPTS = \
	CONFIG_PLATFORM_AUTODETECT=n \
	CONFIG_RTL8821CU=m \
	KVER=$(LINUX_VERSION_PROBED) \
	USER_EXTRA_CFLAGS="$(RPUI_RTL8821CU_USER_EXTRA_CFLAGS)"

$(eval $(kernel-module))
$(eval $(generic-package))
