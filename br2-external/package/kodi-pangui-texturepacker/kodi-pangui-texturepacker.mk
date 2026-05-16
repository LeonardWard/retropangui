################################################################################
#
# kodi-pangui-texturepacker - Host TexturePacker for kodi-pangui (21.3-Omega)
#
################################################################################

KODI_PANGUI_TEXTUREPACKER_VERSION = 21.3-Omega
KODI_PANGUI_TEXTUREPACKER_SITE = $(call github,xbmc,xbmc,$(KODI_PANGUI_TEXTUREPACKER_VERSION))
KODI_PANGUI_TEXTUREPACKER_LICENSE = GPL-2.0
KODI_PANGUI_TEXTUREPACKER_LICENSE_FILES = LICENSE.md

HOST_KODI_PANGUI_TEXTUREPACKER_SUBDIR = tools/depends/native/TexturePacker/src
HOST_KODI_PANGUI_TEXTUREPACKER_DEPENDENCIES = \
	host-giflib \
	host-libjpeg \
	host-libpng \
	host-lzo

HOST_KODI_PANGUI_TEXTUREPACKER_CONF_OPTS = \
	-DKODI_SOURCE_DIR=$(@D) \
	-DCMAKE_CXX_FLAGS="$(HOST_CXXFLAGS) -std=c++17 -DTARGET_POSIX -DTARGET_LINUX -D_LINUX -I$(@D)/xbmc/linux" \
	-Wno-dev

# cmake install puts TexturePacker in $(HOST_DIR)/bin/; rename to kodi-TexturePacker
define HOST_KODI_PANGUI_TEXTUREPACKER_INSTALL_CMDS
	$(HOST_DIR)/bin/cmake --install $(@D)/tools/depends/native/TexturePacker/src \
		--prefix $(HOST_DIR)
	mv -f $(HOST_DIR)/bin/TexturePacker $(HOST_DIR)/bin/kodi-TexturePacker
endef

$(eval $(host-cmake-package))
