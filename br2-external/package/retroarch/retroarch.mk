################################################################################
#
# retroarch
#
################################################################################

RETROARCH_VERSION = v1.22.2
RETROARCH_SITE = https://github.com/libretro/RetroArch
RETROARCH_SITE_METHOD = git
RETROARCH_GIT_SUBMODULES = YES
RETROARCH_LICENSE = GPL-3.0
RETROARCH_LICENSE_FILES = COPYING

RETROARCH_DEPENDENCIES = \
	sdl2 \
	mesa3d \
	libdrm \
	alsa-lib \
	libcurl \
	freetype \
	zlib \
	vulkan-loader \
	ffmpeg

RETROARCH_CONF_OPTS = \
	--disable-cg \
	--disable-jack \
	--disable-oss \
	--disable-pulse \
	--disable-coreaudio \
	--disable-dsound \
	--disable-rsound \
	--disable-roar \
	--disable-al \
	--disable-x11 \
	--disable-wayland \
	--enable-rgui \
	--enable-xmb \
	--enable-ozone \
	--enable-materialui \
	--disable-qt \
	--disable-metal \
	--enable-vulkan \
	--disable-opengl \
	--disable-opengl_core \
	--enable-opengles \
	--enable-opengles3 \
	--enable-kms \
	--enable-egl \
	--enable-sdl2 \
	--enable-alsa \
	--enable-freetype \
	--enable-zlib \
	--enable-threads \
	--enable-dylib \
	--enable-udev \
	--enable-7zip \
	--enable-networking \
	--enable-translate \
	--enable-ffmpeg \
	--enable-builtinflac \
	--disable-v4l2 \
	--disable-discord \
	--disable-builtinzlib \
	--disable-update_assets \
	--disable-update_cores \
	--prefix=/opt/retropangui

RETROARCH_CONF_ENV = \
	PKG_CONF_PATH="$(PKG_CONFIG_HOST_BINARY)" \
	PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
	PKG_CONFIG_LIBDIR="$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/usr/share/pkgconfig" \
	PKG_CONFIG_SYSROOT_DIR="$(STAGING_DIR)"

define RETROARCH_CONFIGURE_CMDS
	(cd $(@D) && \
		$(TARGET_MAKE_ENV) \
		$(TARGET_CONFIGURE_OPTS) \
		$(RETROARCH_CONF_ENV) \
		./configure \
		--host=$(GNU_TARGET_NAME) \
		$(RETROARCH_CONF_OPTS))
endef

define RETROARCH_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" \
		CXX="$(TARGET_CXX)" \
		AR="$(TARGET_AR)" \
		RANLIB="$(TARGET_RANLIB)" \
		STRIP="$(TARGET_STRIP)" \
		OBJCOPY="$(TARGET_OBJCOPY)" \
		HAVE_LANGEXTRA=1
endef

define RETROARCH_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/retroarch \
		$(TARGET_DIR)/opt/retropangui/bin/retroarch
	mkdir -p $(TARGET_DIR)/opt/retropangui/libretrocores
	$(INSTALL) -D -m 0644 $(@D)/retroarch.cfg \
		$(TARGET_DIR)/opt/retropangui/retroarch.cfg
	# Ozone/XMB 메뉴에 필요한 assets (폰트, 텍스처 등)
	# rootfs-overlay의 파일이 나중에 덮어쓰므로 폰트 교체 가능
	mkdir -p $(TARGET_DIR)/opt/retropangui/share/retroarch
	if [ -d $(@D)/media ]; then \
		cp -r $(@D)/media/. $(TARGET_DIR)/opt/retropangui/share/retroarch/; \
	fi
endef

$(eval $(generic-package))
