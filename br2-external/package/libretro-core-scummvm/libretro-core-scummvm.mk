################################################################################
#
# libretro-core-scummvm - Point-and-click adventures
#
# 2026-07-14: libretro-cores.mk에서 분리(todo-20260712-libretro-cores-package-split).
# 빌드 커맨드는 원본과 동일.
#
################################################################################

LIBRETRO_CORE_SCUMMVM_VERSION = libretro-v3.1.0.1
LIBRETRO_CORE_SCUMMVM_SITE = https://github.com/libretro/scummvm
LIBRETRO_CORE_SCUMMVM_SOURCE =
LIBRETRO_CORE_SCUMMVM_DEPENDENCIES = mesa3d
LIBRETRO_CORE_SCUMMVM_LICENSE = GPL-2.0

# configure_submodules.sh가 의존하는 두 서브레포
LIBRETRO_CORE_SCUMMVM_DEPS_PATH = $(@D)/scummvm/backends/platform/libretro/deps
LIBRETRO_CORE_SCUMMVM_DEPS_URL    = https://github.com/libretro/libretro-deps
LIBRETRO_CORE_SCUMMVM_DEPS_COMMIT = 7e6e34f0319f4c7448d72f0e949e76265ccf55a1
LIBRETRO_CORE_SCUMMVM_COMMON_URL    = https://github.com/libretro/libretro-common
LIBRETRO_CORE_SCUMMVM_COMMON_COMMIT = 70ed90c42ddea828f53dd1b984c6443ddb39dbd6

define LIBRETRO_CORE_SCUMMVM_BUILD_CMDS
	test -d $(@D)/scummvm/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_SCUMMVM_SITE) $(@D)/scummvm
	git -C $(@D)/scummvm checkout $(LIBRETRO_CORE_SCUMMVM_VERSION)
	mkdir -p $(LIBRETRO_CORE_SCUMMVM_DEPS_PATH)
	# libretro-deps: configure_submodules.sh는 commit hash fetch로 실패하므로 직접 클론
	test -f $(LIBRETRO_CORE_SCUMMVM_DEPS_PATH)/libretro-deps/Makefile || \
		(rm -rf $(LIBRETRO_CORE_SCUMMVM_DEPS_PATH)/libretro-deps && \
		 git clone --filter=blob:none $(LIBRETRO_CORE_SCUMMVM_DEPS_URL) $(LIBRETRO_CORE_SCUMMVM_DEPS_PATH)/libretro-deps && \
		 git -C $(LIBRETRO_CORE_SCUMMVM_DEPS_PATH)/libretro-deps checkout $(LIBRETRO_CORE_SCUMMVM_DEPS_COMMIT))
	# libretro-common: 동일
	test -f $(LIBRETRO_CORE_SCUMMVM_DEPS_PATH)/libretro-common/README.md || \
		(rm -rf $(LIBRETRO_CORE_SCUMMVM_DEPS_PATH)/libretro-common && \
		 git clone --filter=blob:none $(LIBRETRO_CORE_SCUMMVM_COMMON_URL) $(LIBRETRO_CORE_SCUMMVM_DEPS_PATH)/libretro-common && \
		 git -C $(LIBRETRO_CORE_SCUMMVM_DEPS_PATH)/libretro-common checkout $(LIBRETRO_CORE_SCUMMVM_COMMON_COMMIT))
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/scummvm/backends/platform/libretro \
		CC="$(TARGET_CC)" \
		CXX="$(TARGET_CXX)" \
		AR="$(TARGET_AR) cru" \
		RANLIB="$(TARGET_RANLIB)" \
		STRIP="$(TARGET_STRIP)" \
		OBJCOPY="$(TARGET_OBJCOPY)" \
		platform=unix \
		BUILD_64BIT=1
endef

define LIBRETRO_CORE_SCUMMVM_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-scummvm
	$(INSTALL) -m 0644 $(@D)/scummvm/backends/platform/libretro/scummvm_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-scummvm/
	echo "scummvm_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-scummvm/.installed_so_name
	mkdir -p $(TARGET_DIR)/usr/share/retropangui/bundled-bios/scummvm
	$(INSTALL) -m 0644 $(@D)/scummvm/gui/themes/gui-icons.dat \
		$(TARGET_DIR)/usr/share/retropangui/bundled-bios/scummvm/
	$(INSTALL) -m 0644 $(@D)/scummvm/gui/themes/scummclassic.zip \
		$(TARGET_DIR)/usr/share/retropangui/bundled-bios/scummvm/
	$(INSTALL) -m 0644 $(@D)/scummvm/gui/themes/scummmodern.zip \
		$(TARGET_DIR)/usr/share/retropangui/bundled-bios/scummvm/
endef

$(eval $(generic-package))
