################################################################################
#
# kodi-pangui - Kodi Media Center
# Platform: GBM (KMS/DRM, GLES2) - Mali DDK, 임베디드 환경용
#
################################################################################

KODI_PANGUI_VERSION = 21.3-Omega
KODI_PANGUI_SITE = https://github.com/xbmc/xbmc
KODI_PANGUI_SITE_METHOD = git
KODI_PANGUI_LICENSE = GPL-2.0
KODI_PANGUI_LICENSE_FILES = LICENSE.md

KODI_PANGUI_DEPENDENCIES = \
	mali-ddk \
	mesa3d \
	libass \
	libfribidi \
	freetype \
	fontconfig \
	sqlite \
	libxml2 \
	libpng \
	giflib \
	jpeg \
	zlib \
	openssl \
	libcurl \
	pcre \
	pcre2 \
	taglib \
	tinyxml \
	tinyxml2 \
	flatbuffers \
	python3 \
	fstrcmp \
	libcdio \
	libcrossguid \
	libdisplay-info \
	libdrm \
	libudfread \
	libinput \
	libxkbcommon \
	alsa-lib \
	eudev \
	lzo \
	expat \
	host-cmake \
	host-python3 \
	host-flatbuffers \
	host-swig \
	host-kodi-pangui-texturepacker

KODI_PANGUI_CONF_OPTS = \
	-DCORE_PLATFORM_NAME=gbm \
	-DAPP_RENDER_SYSTEM=gles \
	-DENABLE_OPENGL=OFF \
	-DENABLE_OPENGLES=ON \
	-DENABLE_X11=OFF \
	-DENABLE_WAYLAND=OFF \
	-DENABLE_PULSEAUDIO=OFF \
	-DENABLE_ALSA=ON \
	-DENABLE_VAAPI=OFF \
	-DENABLE_VDPAU=OFF \
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
	-DENABLE_INTERNAL_CROSSGUID=OFF \
	-DENABLE_INTERNAL_KISSFFT=ON \
	-DENABLE_INTERNAL_FMT=ON \
	-DENABLE_INTERNAL_SPDLOG=ON \
	-DENABLE_INTERNAL_RAPIDJSON=OFF \
	-DENABLE_INTERNAL_UDFREAD=OFF \
	-DENABLE_INTERNAL_FLATBUFFERS=OFF \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=/usr \
	-Dlibdvdread_URL="" \
	-Dlibdvdnav_URL="" \
	-Dlibdvdcss_URL="" \
	-DHOST_CAN_EXECUTE_TARGET=FALSE \
	-DNATIVEPREFIX=$(HOST_DIR) \
	-DDEPENDS_PATH=$(STAGING_DIR)/usr \
	-DWITH_TEXTUREPACKER=$(HOST_DIR)/bin/ \
	-DFLATBUFFERS_FLATC_EXECUTABLE=$(HOST_DIR)/bin/flatc \
	-DENABLE_GOLD=OFF \
	-DCLANG_FORMAT_EXECUTABLE=OFF \
	-DKODI_DEPENDSBUILD=OFF \
	-DWITH_JSONSCHEMABUILDER=$(HOST_DIR)/bin \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DCMAKE_SYSTEM_PROCESSOR=aarch64

KODI_PANGUI_CONF_ENV = \
	PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
	PKG_CONFIG_LIBDIR="$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/usr/share/pkgconfig" \
	PKG_CONFIG_SYSROOT_DIR="$(STAGING_DIR)"

KODI_PANGUI_INSTALL_STAGING = YES
KODI_PANGUI_SUPPORTS_IN_SOURCE_BUILD = NO

# staging install 시 Textures.xbt가 없으면 cmake --install이 실패한다.
# TexturePacker는 클린 빌드 시에만 실행되므로 incremental 빌드에서 이 파일이 없다.
# peripheral.joystick 빌드에 필요한 헤더/cmake는 같은 cmake --install로 설치되므로
# 빈 파일을 미리 만들어 cmake install이 통과하도록 한다.
define KODI_PANGUI_INSTALL_STAGING_CMDS
	mkdir -p $(@D)/buildroot-build/addons/skin.estuary/media
	test -f $(@D)/buildroot-build/addons/skin.estuary/media/Textures.xbt || \
		touch $(@D)/buildroot-build/addons/skin.estuary/media/Textures.xbt
	$(HOST_DIR)/bin/cmake --install $(@D)/buildroot-build --prefix $(STAGING_DIR)/usr
endef

# cmake FetchContent tries to download Groovy/Apache Commons JARs at configure time.
# Pre-download them so cmake finds them in TARBALL_DIR and skips network access.
KODI_PANGUI_GROOVY_VER = 4.0.26
KODI_PANGUI_COMMONS_LANG_VER = 3.17.0
KODI_PANGUI_COMMONS_TEXT_VER = 1.13.0
KODI_MIRROR = https://mirrors.kodi.tv

# cmake checks for extracted JARs at DEPENDS_PATH/share/ — pre-extract using system wget
# (cmake's embedded curl has no https support and fails on kodi mirror redirects)
define KODI_PANGUI_PRE_CONFIGURE_GROOVY_DEPS
	mkdir -p "$(@D)/buildroot-build/build/download"
	DL="$(@D)/buildroot-build/build/download"; \
	for f in ffmpeg-6.0.1.tar.gz \
	          crossguid-ca1bf4b810e2d188d04cb6286f957008ee1b7681.tar.gz \
	          libudfread-1.1.2.tar.gz \
	          fmt-9.1.0.tar.gz \
	          spdlog-1.10.0.tar.gz; do \
	    [ -s "$$DL/$$f" ] || { rm -f "$$DL/$$f" && \
	        wget -qL --no-check-certificate "$(KODI_MIRROR)/build-deps/sources/$$f" \
	            -O "$$DL/$$f" || { echo "ERROR: failed to pre-download $$f" >&2; exit 1; }; }; \
	done; \
	[ -s "$$DL/libdvdread-6.1.3-Next-Nexus-Alpha2-2.tar.gz" ] || \
	    { rm -f "$$DL/libdvdread-6.1.3-Next-Nexus-Alpha2-2.tar.gz" && \
	      wget -qL --no-check-certificate \
	        "https://github.com/xbmc/libdvdread/archive/6.1.3-Next-Nexus-Alpha2-2.tar.gz" \
	        -O "$$DL/libdvdread-6.1.3-Next-Nexus-Alpha2-2.tar.gz" || \
	      { echo "ERROR: failed to pre-download libdvdread" >&2; exit 1; }; }; \
	[ -s "$$DL/libdvdnav-6.1.1-Next-Nexus-Alpha2-2.tar.gz" ] || \
	    { rm -f "$$DL/libdvdnav-6.1.1-Next-Nexus-Alpha2-2.tar.gz" && \
	      wget -qL --no-check-certificate \
	        "https://github.com/xbmc/libdvdnav/archive/6.1.1-Next-Nexus-Alpha2-2.tar.gz" \
	        -O "$$DL/libdvdnav-6.1.1-Next-Nexus-Alpha2-2.tar.gz" || \
	      { echo "ERROR: failed to pre-download libdvdnav" >&2; exit 1; }; }
	if [ ! -f "$(STAGING_DIR)/usr/share/groovy/lib/groovy-$(KODI_PANGUI_GROOVY_VER).jar" ]; then \
		TMP=$$(mktemp -d) && \
		wget -qL "$(KODI_MIRROR)/build-deps/sources/apache-groovy-binary-$(KODI_PANGUI_GROOVY_VER).zip" \
			-O "$$TMP/groovy.zip" && \
		unzip -q "$$TMP/groovy.zip" -d "$$TMP/groovy-extract" && \
		mkdir -p "$(STAGING_DIR)/usr/share/groovy" && \
		cp -r "$$TMP/groovy-extract/groovy-$(KODI_PANGUI_GROOVY_VER)/." \
			"$(STAGING_DIR)/usr/share/groovy/" && \
		rm -rf "$$TMP"; \
	fi
	if [ ! -f "$(STAGING_DIR)/usr/share/java/lang/commons-lang3-$(KODI_PANGUI_COMMONS_LANG_VER).jar" ]; then \
		TMP=$$(mktemp -d) && \
		wget -qL "$(KODI_MIRROR)/build-deps/sources/commons-lang3-$(KODI_PANGUI_COMMONS_LANG_VER)-bin.tar.gz" \
			-O "$$TMP/lang.tar.gz" && \
		mkdir -p "$(STAGING_DIR)/usr/share/java/lang" && \
		tar -xzf "$$TMP/lang.tar.gz" --strip-components=1 \
			-C "$(STAGING_DIR)/usr/share/java/lang" && \
		rm -rf "$$TMP"; \
	fi
	if [ ! -f "$(STAGING_DIR)/usr/share/java/text/commons-text-$(KODI_PANGUI_COMMONS_TEXT_VER).jar" ]; then \
		TMP=$$(mktemp -d) && \
		wget -qL "$(KODI_MIRROR)/build-deps/sources/commons-text-$(KODI_PANGUI_COMMONS_TEXT_VER)-bin.tar.gz" \
			-O "$$TMP/text.tar.gz" && \
		mkdir -p "$(STAGING_DIR)/usr/share/java/text" && \
		tar -xzf "$$TMP/text.tar.gz" --strip-components=1 \
			-C "$(STAGING_DIR)/usr/share/java/text" && \
		rm -rf "$$TMP"; \
	fi
endef
KODI_PANGUI_PRE_CONFIGURE_HOOKS += KODI_PANGUI_PRE_CONFIGURE_GROOVY_DEPS

# Build JsonSchemaBuilder with host (x86_64) compiler before cmake configure.
# WITH_JSONSCHEMABUILDER tells Kodi cmake to use this binary directly, skipping
# the ExternalProject_Add that would otherwise build an aarch64 binary and overwrite it.
define KODI_PANGUI_PRE_CONFIGURE_JSB
	echo "Building JsonSchemaBuilder with host compiler..." && \
	/usr/bin/g++ -std=c++17 -O2 \
	    -I"$(@D)/lib/rapidjson/include" \
	    "$(@D)/tools/depends/native/JsonSchemaBuilder/src/JsonSchemaBuilder.cpp" \
	    -o "$(HOST_DIR)/bin/JsonSchemaBuilder" || \
	{ echo "ERROR: failed to build JsonSchemaBuilder" >&2; exit 1; }
endef
KODI_PANGUI_PRE_CONFIGURE_HOOKS += KODI_PANGUI_PRE_CONFIGURE_JSB

# Buildroot's ffmpeg package (older version) installs shared libs (.so) to the sysroot
# that conflict with Kodi's internally-built ffmpeg static libs (.a).
# Remove any stale ffmpeg shared libs so the linker uses the correct internal static libs.
define KODI_PANGUI_PRE_BUILD_CLEAN_SYSTEM_FFMPEG
	for lib in avutil avcodec avformat avfilter avdevice swresample swscale postproc; do \
	    rm -f "$(STAGING_DIR)/usr/lib/lib$${lib}.so"* ; \
	done
endef
KODI_PANGUI_PRE_BUILD_HOOKS += KODI_PANGUI_PRE_BUILD_CLEAN_SYSTEM_FFMPEG

# FindFFMPEG.cmake only passes CROSSCOMPILING to the ffmpeg sub-cmake when
# KODI_DEPENDSBUILD=ON (which we don't use). Patch it to always pass the needed
# cross-compilation variables so ffmpeg ./configure gets --enable-cross-compile.
# Re-runs cmake configure and clears ffmpeg stamps only when something changed.
define KODI_PANGUI_PRE_BUILD_CROSS_FIX
	FINDFFMPEG="$(@D)/cmake/modules/FindFFMPEG.cmake"; \
	CACHE="$(@D)/buildroot-build/CMakeCache.txt"; \
	NEEDS_RECONFIGURE=0; \
	if [ -f "$$FINDFFMPEG" ] && ! grep -q 'pangui_cross_patch' "$$FINDFFMPEG"; then \
	    echo "Patching FindFFMPEG.cmake to pass CROSSCOMPILING to ffmpeg sub-cmake..." && \
	    sed -i 's|$${CROSS_ARGS}|$${CROSS_ARGS}\n                 -DCROSSCOMPILING=$${CMAKE_CROSSCOMPILING}\n                 -DCMAKE_AR=$${CMAKE_AR}\n                 -DCMAKE_RANLIB=$${CMAKE_RANLIB}\n                 -DCMAKE_STRIP=$${CMAKE_STRIP}  # pangui_cross_patch|' \
	        "$$FINDFFMPEG" && \
	    NEEDS_RECONFIGURE=1 && echo "FindFFMPEG.cmake patched."; \
	fi; \
	if ! grep -q "^CMAKE_SYSTEM_PROCESSOR:STRING=aarch64" "$$CACHE" 2>/dev/null; then \
	    NEEDS_RECONFIGURE=1; \
	fi; \
	if grep -q "^ENABLE_VAAPI:.*=\(AUTO\|ON\)" "$$CACHE" 2>/dev/null; then \
	    echo "ENABLE_VAAPI not OFF in cache, forcing reconfigure..." && \
	    NEEDS_RECONFIGURE=1; \
	fi; \
	if [ "$$NEEDS_RECONFIGURE" = "1" ]; then \
	    echo "Re-running cmake configure for cross-compile fix..." && \
	    $(KODI_PANGUI_CONF_ENV) $(HOST_DIR)/bin/cmake \
	        -S "$(@D)" -B "$(@D)/buildroot-build" \
	        -DCMAKE_SYSTEM_NAME=Linux \
	        -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
	        -DENABLE_VAAPI=OFF \
	        -DENABLE_VDPAU=OFF && \
	    rm -f "$(@D)/buildroot-build/build/ffmpeg/src/ffmpeg-stamp/ffmpeg-cmake" \
	          "$(@D)/buildroot-build/build/ffmpeg/src/ffmpeg-stamp/ffmpeg-configure" && \
	    echo "ffmpeg stamps cleared."; \
	fi
endef
KODI_PANGUI_PRE_BUILD_HOOKS += KODI_PANGUI_PRE_BUILD_CROSS_FIX

define KODI_PANGUI_INSTALL_DATA
	mkdir -p $(TARGET_DIR)/usr/share/kodi
endef

KODI_PANGUI_POST_INSTALL_TARGET_HOOKS += KODI_PANGUI_INSTALL_DATA

$(eval $(cmake-package))
