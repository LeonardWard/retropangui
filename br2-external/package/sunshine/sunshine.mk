################################################################################
#
# sunshine
#
################################################################################

SUNSHINE_VERSION = v2026.516.143833
SUNSHINE_SITE = https://github.com/LizardByte/Sunshine
SUNSHINE_SITE_METHOD = git
SUNSHINE_GIT_SUBMODULES = YES
SUNSHINE_LICENSE = GPL-3.0-only
SUNSHINE_LICENSE_FILES = LICENSE

# Sunshine's CMake requires Boost 1.89.0 EXACT (find_package(... EXACT)) -
# this project's Buildroot boost package is 1.83.0, so the version check
# always fails and CMake falls back to FetchContent, downloading and
# building its own Boost from source at configure/build time. Not adding
# BR2_PACKAGE_BOOST here on purpose - it would just be wasted build time.
SUNSHINE_DEPENDENCIES = \
	libdrm \
	libminiupnpc \
	opus \
	libevdev \
	eudev \
	numactl \
	json-for-modern-cpp \
	pulseaudio \
	libva \
	xlib_libX11 \
	host-python-jinja2

# Sunshine's CMake fetches Boost 1.89.0 source and prebuilt FFmpeg static
# libs (LizardByte/build-deps) over HTTPS mid-configure via CMake
# file(DOWNLOAD)/FetchContent. This project's host-cmake is built with
# -DCMAKE_USE_OPENSSL:BOOL=OFF (buildroot/package/cmake/cmake.mk) - its
# bundled curl has no TLS backend at all ("Protocol https not supported"),
# so those in-configure downloads always fail. Fetch both archives through
# Buildroot's own (working) downloader instead, and point CMake at the
# already-extracted local copies so it skips its own download step.
#
# Sunshine's web-ui CMake target hard-requires npm (find_program(NPM npm
# REQUIRED), no option to skip - the web config/pairing UI is built into
# the same target as the rest of the install). This project's Buildroot
# ships host-nodejs-bin pinned to 20.11.1 (buildroot/package/nodejs/nodejs.mk)
# - one minor version short of the crypto.hash() API that Sunshine's pinned
# Vite/@vitejs/plugin-vue needs (added in Node 20.12/21.7), so the web-ui
# build fails with "crypto.hash is not a function". Fetch a current Node.js
# LTS (linux-x64, host build machine) through Buildroot's own downloader -
# same version (24.18.0) this project's rpui-nodejs already uses for the
# aarch64 target - and put its bin/ ahead of PATH for both configure and
# build so npm resolves to it instead of the stale Buildroot one.
SUNSHINE_EXTRA_DOWNLOADS = \
	https://github.com/boostorg/boost/releases/download/boost-1.89.0/boost-1.89.0-cmake.tar.xz \
	https://github.com/LizardByte/build-deps/releases/download/v2026.713.132551/Linux-aarch64-ffmpeg.tar.gz \
	https://nodejs.org/dist/v24.18.0/node-v24.18.0-linux-x64.tar.xz

define SUNSHINE_EXTRACT_PREFETCHED_DEPS
	mkdir -p $(@D)/_prefetched-deps
	tar -xJf $(SUNSHINE_DL_DIR)/boost-1.89.0-cmake.tar.xz -C $(@D)/_prefetched-deps
	tar -xzf $(SUNSHINE_DL_DIR)/Linux-aarch64-ffmpeg.tar.gz -C $(@D)/_prefetched-deps
	tar -xJf $(SUNSHINE_DL_DIR)/node-v24.18.0-linux-x64.tar.xz -C $(@D)/_prefetched-deps
endef
SUNSHINE_PRE_CONFIGURE_HOOKS += SUNSHINE_EXTRACT_PREFETCHED_DEPS

SUNSHINE_FRESH_NODE_PATH = $(@D)/_prefetched-deps/node-v24.18.0-linux-x64/bin

# odroidc5 minimal build: DRM/KMS capture only, no desktop session
# (X11/Wayland/KWin/Portal), no discrete GPU paths (VAAPI/Vulkan/CUDA),
# no system tray. Software x264 encoding only in this pass - hardware
# encoder integration (hcodec_rst reset, V4L2 M2M wrapper) is a separate,
# deliberately deferred task (see todo-20260709-remote-streaming.html).
SUNSHINE_CONF_OPTS = \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=/usr \
	-DBUILD_DOCS=OFF \
	-DBUILD_TESTS=OFF \
	-DSUNSHINE_ENABLE_TRAY=OFF \
	-DSUNSHINE_ENABLE_X11=OFF \
	-DSUNSHINE_ENABLE_WAYLAND=OFF \
	-DSUNSHINE_ENABLE_PORTAL=OFF \
	-DSUNSHINE_ENABLE_KWIN=OFF \
	-DSUNSHINE_ENABLE_VAAPI=OFF \
	-DSUNSHINE_ENABLE_VULKAN=OFF \
	-DSUNSHINE_ENABLE_CUDA=OFF \
	-DCUDA_FAIL_ON_MISSING=OFF \
	-DSUNSHINE_ENABLE_DRM=ON \
	-DFETCHCONTENT_SOURCE_DIR_BOOST=$(@D)/_prefetched-deps/boost-1.89.0 \
	-DFFMPEG_PREPARED_BINARIES=$(@D)/_prefetched-deps/ffmpeg

SUNSHINE_CONF_ENV = \
	PATH=$(SUNSHINE_FRESH_NODE_PATH):$(BR_PATH) \
	PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
	PKG_CONFIG_LIBDIR="$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/usr/share/pkgconfig" \
	PKG_CONFIG_SYSROOT_DIR="$(STAGING_DIR)"

# cmake-package's build step defaults to _BUILD_ENV = _MAKE_ENV, not
# _CONF_ENV - the fresh-node PATH override has to be repeated here or
# `npm run build` (build stage) falls back to the stale host-nodejs-bin
# even though `find_program(NPM)` (configure stage) found the fresh one.
SUNSHINE_MAKE_ENV = \
	PATH=$(SUNSHINE_FRESH_NODE_PATH):$(BR_PATH)

# Several of Sunshine's CMake subprojects (third-party/inputtino, the
# FetchContent-built Boost under _deps/boost-build, the glad2-cmake GL/EGL
# loader, third-party/libdisplaydevice) are pulled in via add_subdirectory()
# and either guard their own install() rules with
# `if (CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME)` (always false when
# add_subdirectory'd) or just never define install() rules at all - none of
# their .so's end up in `cmake --install`'s output, and sunshine fails to
# start with "cannot open shared object file: <name>.so" one at a time
# (inputtino, then boost, then glad, then libdisplaydevice - found across
# 4 separate on-device tests, 2026-07-16). Rather than keep whack-a-moling
# one hand-picked path per missing library, sweep the whole build tree for
# any .so this specific build actually produced and copy all of them.
# Excludes are vendor source/test trees that happen to contain .so-named
# files but were never linked into the sunshine binary (_prefetched-deps is
# raw downloaded Boost source, build-deps is AMD's own bundled FFmpeg/AMF
# test binaries for a codec path we don't use, node_modules is the web-ui's
# own JS toolchain).
define SUNSHINE_INSTALL_BUNDLED_LIBS
	mkdir -p $(TARGET_DIR)/usr/lib
	find $(@D) -iname '*.so*' -type f \
		-not -path '*/_prefetched-deps/*' \
		-not -path '*/third-party/build-deps/*' \
		-not -path '*/node_modules/*' \
		-exec cp -aL {} $(TARGET_DIR)/usr/lib/ \;
endef
SUNSHINE_POST_INSTALL_TARGET_HOOKS += SUNSHINE_INSTALL_BUNDLED_LIBS

$(eval $(cmake-package))
