################################################################################
#
# kodi - Kodi Media Center
# Platform: GBM (KMS/DRM, GLES2) - X11/Wayland 없는 임베디드 환경용
# Version:  21.2 "Omega" (latest stable)
#
################################################################################

KODI_VERSION = 21.2-Omega
KODI_SITE = https://github.com/xbmc/xbmc
KODI_SITE_METHOD = git
KODI_LICENSE = GPL-2.0
KODI_LICENSE_FILES = LICENSE.md

KODI_DEPENDENCIES = \
	ffmpeg \
	libass \
	fribidi \
	freetype \
	fontconfig \
	sqlite \
	libxml2 \
	libpng \
	libjpeg \
	zlib \
	openssl \
	libcurl \
	pcre2 \
	tinyxml2 \
	flatbuffers \
	python3 \
	libinput \
	libxkbcommon \
	alsa-lib \
	libudev \
	lzo \
	expat \
	host-cmake \
	host-python3 \
	host-flatbuffers

# crossguid, kissfft, fmt, spdlog, rapidjson 등은 Kodi가 내부에서 빌드
KODI_CONF_OPTS = \
	-DCORE_PLATFORM_NAME=gbm \
	-DGBM_RENDER_SYSTEM=gles \
	-DENABLE_OPENGL=OFF \
	-DENABLE_OPENGLES=ON \
	-DENABLE_X11=OFF \
	-DENABLE_WAYLAND=OFF \
	-DENABLE_PULSEAUDIO=OFF \
	-DENABLE_ALSA=ON \
	-DENABLE_UDEV=ON \
	-DENABLE_DBUS=OFF \
	-DENABLE_AVAHI=OFF \
	-DENABLE_BLURAY=OFF \
	-DENABLE_MARIADBCLIENT=OFF \
	-DENABLE_MYSQLCLIENT=OFF \
	-DENABLE_NFS=OFF \
	-DENABLE_SMBCLIENT=OFF \
	-DENABLE_UPNP=ON \
	-DENABLE_OPTICAL=OFF \
	-DENABLE_DVDCSS=OFF \
	-DENABLE_TESTING=OFF \
	-DENABLE_INTERNAL_CROSSGUID=ON \
	-DENABLE_INTERNAL_KISSFFT=ON \
	-DENABLE_INTERNAL_FMT=ON \
	-DENABLE_INTERNAL_SPDLOG=ON \
	-DENABLE_INTERNAL_RAPIDJSON=ON \
	-DENABLE_INTERNAL_FLATBUFFERS=OFF \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=/usr \
	-Dlibdvdread_URL="" \
	-Dlibdvdnav_URL="" \
	-Dlibdvdcss_URL=""

KODI_CONF_ENV = \
	PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
	PKG_CONFIG_LIBDIR="$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/usr/share/pkgconfig" \
	PKG_CONFIG_SYSROOT_DIR="$(STAGING_DIR)"

# Kodi는 빌드 시 호스트 도구(TexturePacker 등)를 내부 빌드함
# 크로스컴파일 시 호스트/타겟 빌드를 분리하기 위해 DEPENDS_ON_HOST 사용
KODI_SUPPORTS_IN_SOURCE_BUILD = NO

# Kodi 데이터 파일(스킨, 언어팩 등) 설치
define KODI_INSTALL_DATA
	mkdir -p $(TARGET_DIR)/usr/share/kodi
endef

KODI_POST_INSTALL_TARGET_HOOKS += KODI_INSTALL_DATA

$(eval $(cmake-package))
