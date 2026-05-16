################################################################################
#
# kodi-pangui-jsonschemabuilder - Host JsonSchemaBuilder for kodi-pangui (21.3-Omega)
#
################################################################################

KODI_PANGUI_JSONSCHEMABUILDER_VERSION = 21.3-Omega
KODI_PANGUI_JSONSCHEMABUILDER_SITE = $(call github,xbmc,xbmc,$(KODI_PANGUI_JSONSCHEMABUILDER_VERSION))
KODI_PANGUI_JSONSCHEMABUILDER_LICENSE = GPL-2.0
KODI_PANGUI_JSONSCHEMABUILDER_LICENSE_FILES = LICENSE.md

HOST_KODI_PANGUI_JSONSCHEMABUILDER_SUBDIR = tools/depends/native/JsonSchemaBuilder

HOST_KODI_PANGUI_JSONSCHEMABUILDER_CONF_OPTS = \
	-DCMAKE_CXX_FLAGS="$(HOST_CXXFLAGS) -std=c++17" \
	-Wno-dev

define HOST_KODI_PANGUI_JSONSCHEMABUILDER_INSTALL_CMDS
	$(HOST_DIR)/bin/cmake --install $(@D)/tools/depends/native/JsonSchemaBuilder \
		--prefix $(HOST_DIR)
endef

$(eval $(host-cmake-package))
