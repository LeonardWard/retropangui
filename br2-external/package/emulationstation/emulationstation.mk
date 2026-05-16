################################################################################
#
# emulationstation
#
################################################################################

EMULATIONSTATION_VERSION = main
EMULATIONSTATION_SITE = https://github.com/LeonardWard/retropangui-emulationstation
EMULATIONSTATION_SITE_METHOD = git
EMULATIONSTATION_GIT_SUBMODULES = YES
EMULATIONSTATION_LICENSE = MIT
EMULATIONSTATION_LICENSE_FILES = LICENSE.md

EMULATIONSTATION_DEPENDENCIES = \
	sdl2 \
	mesa3d \
	freeimage \
	freetype \
	vlc \
	libcurl \
	alsa-lib \
	rapidjson

EMULATIONSTATION_CONF_OPTS = \
	-DGLES=On \
	-DUSE_MESA_GLES=Off \
	-DGL=OFF \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=/usr \
	-DCMAKE_CXX_FLAGS="-Wno-unused-variable" \
	-DCMAKE_C_FLAGS="-Wno-unused-variable"

EMULATIONSTATION_CONF_ENV = \
	PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
	PKG_CONFIG_LIBDIR="$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/usr/share/pkgconfig" \
	PKG_CONFIG_SYSROOT_DIR="$(STAGING_DIR)"

define EMULATIONSTATION_INSTALL_RESOURCES
	cp -r $(@D)/resources $(TARGET_DIR)/usr/bin/resources
endef

EMULATIONSTATION_POST_INSTALL_TARGET_HOOKS += EMULATIONSTATION_INSTALL_RESOURCES

$(eval $(cmake-package))
