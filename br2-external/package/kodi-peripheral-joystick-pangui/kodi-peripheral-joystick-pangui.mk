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

KODI_PERIPHERAL_JOYSTICK_PANGUI_CONF_OPTS = \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DCMAKE_SYSTEM_PROCESSOR=aarch64 \
	-DCORE_SYSTEM_NAME=linux

KODI_PERIPHERAL_JOYSTICK_PANGUI_CONF_ENV = \
	PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
	PKG_CONFIG_LIBDIR="$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/usr/share/pkgconfig" \
	PKG_CONFIG_SYSROOT_DIR="$(STAGING_DIR)"

$(eval $(cmake-package))
