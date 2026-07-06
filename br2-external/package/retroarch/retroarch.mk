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
	--prefix=/usr

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
		$(TARGET_DIR)/usr/bin/retroarch
	mkdir -p $(TARGET_DIR)/usr/lib/libretro
	# Ozone/XMB 메뉴에 필요한 assets (폰트, 텍스처 등)
	# rootfs-overlay의 파일이 나중에 덮어쓰므로 폰트 교체 가능
	mkdir -p $(TARGET_DIR)/usr/share/retroarch
	if [ -d $(@D)/media ]; then \
		cp -r $(@D)/media/. $(TARGET_DIR)/usr/share/retroarch/; \
	fi
	# 2026-07-07: RA 소스(gfx/drivers_font_renderer/freetype.c)가 OSD
	# 알림 메시지 폰트를 정확히 "assets://pkg/osd-font.ttf"라는 이름으로
	# 찾는데, media/pkg/ 안에는 언어별 폴백 폰트만 있고 그 이름의 파일이
	# 없어서 못 찾고 기본 비트맵 폰트로 떨어짐 - 한글 글리프가 없어서
	# "ㅁㅁㅁ"로 깨짐. user_language=10(한국어)에 맞춰 한글 폴백 폰트를
	# osd-font.ttf 이름으로도 배치.
	if [ -f $(TARGET_DIR)/usr/share/retroarch/pkg/korean-fallback-font.ttf ]; then \
		cp $(TARGET_DIR)/usr/share/retroarch/pkg/korean-fallback-font.ttf \
			$(TARGET_DIR)/usr/share/retroarch/pkg/osd-font.ttf; \
	fi
endef

$(eval $(generic-package))
