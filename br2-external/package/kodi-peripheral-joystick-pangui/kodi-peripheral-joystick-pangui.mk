################################################################################
#
# kodi-peripheral-joystick-pangui - Kodi joystick peripheral addon (Omega)
#
################################################################################

KODI_PERIPHERAL_JOYSTICK_PANGUI_VERSION = 21.1.23-Omega
KODI_PERIPHERAL_JOYSTICK_PANGUI_SITE = $(call github,xbmc,peripheral.joystick,$(KODI_PERIPHERAL_JOYSTICK_PANGUI_VERSION))
KODI_PERIPHERAL_JOYSTICK_PANGUI_LICENSE = GPL-2.0+
KODI_PERIPHERAL_JOYSTICK_PANGUI_LICENSE_FILES = LICENSE.md
KODI_PERIPHERAL_JOYSTICK_PANGUI_DEPENDENCIES = kodi-pangui tinyxml eudev

# KodiConfig.cmake/AddonHelpers.cmake가 KODI_INCLUDE_DIR과 CMAKE_MODULE_PATH에
# sysroot 접두사 없는 타겟 절대경로(/usr/include/kodi, /usr/lib/kodi,
# /usr/share/kodi/cmake)를 하드코딩 기본값으로 쓰는데, 크로스컴파일 중이라
# 호스트엔 저 경로가 없어 include(AddonHelpers)와 file(STRINGS .../versions.h)
# 둘 다 실패한다(CMAKE_FIND_ROOT_PATH는 find_package만 sysroot 재작성하고
# include()/file()은 건드리지 않음). KODI_INCLUDE_DIR은 KodiConfig.cmake가
# "if(NOT ...)"로만 기본값을 채우므로 미리 스테이징 경로로 넘겨 하드코딩을
# 건너뛴다 - 컴파일 타임 include 전용이라 안전.
# 주의: KODI_LIB_DIR은 여기서 오버라이드하면 안 됨 - 이건 애드온의
# install(DESTINATION ${KODI_LIB_DIR})에도 그대로 쓰여서, 스테이징 절대경로로
# 바꾸면 DESTDIR과 겹쳐 붙어 "target//home/builder/..." 같은 잘못된 설치
# 경로가 생긴다(buildroot install-path sanity check가 잡아냄). 원래 타겟
# 절대경로(/usr/lib/kodi) 그대로 둬야 DESTDIR과 정상 결합된다.
KODI_PERIPHERAL_JOYSTICK_PANGUI_CONF_OPTS = \
	-DKODI_INCLUDE_DIR="$(STAGING_DIR)/usr/include/kodi" \
	-DCMAKE_MODULE_PATH="$(STAGING_DIR)/usr/lib/kodi;$(STAGING_DIR)/usr/share/kodi/cmake" \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DCMAKE_SYSTEM_PROCESSOR=aarch64 \
	-DCORE_SYSTEM_NAME=linux

KODI_PERIPHERAL_JOYSTICK_PANGUI_CONF_ENV = \
	PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
	PKG_CONFIG_LIBDIR="$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/usr/share/pkgconfig" \
	PKG_CONFIG_SYSROOT_DIR="$(STAGING_DIR)"

$(eval $(cmake-package))
