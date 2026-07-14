################################################################################
#
# libretro-core-dosbox-pure - DOS
#
# 2026-07-14: libretro-cores.mk에서 분리(todo-20260712-libretro-cores-package-split).
# 빌드 커맨드는 원본과 동일.
#
################################################################################

LIBRETRO_CORE_DOSBOX_PURE_VERSION = f587236b2d016f4f16d672e9ce2829bdf507bf9b
LIBRETRO_CORE_DOSBOX_PURE_SITE = https://github.com/schellingb/dosbox-pure
LIBRETRO_CORE_DOSBOX_PURE_SOURCE =
LIBRETRO_CORE_DOSBOX_PURE_DEPENDENCIES = mesa3d
LIBRETRO_CORE_DOSBOX_PURE_LICENSE = GPL-2.0

LIBRETRO_CORE_DOSBOX_PURE_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_DOSBOX_PURE_BUILD_CMDS
	test -d $(@D)/dosbox-pure/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_DOSBOX_PURE_SITE) $(@D)/dosbox-pure
	git -C $(@D)/dosbox-pure checkout $(LIBRETRO_CORE_DOSBOX_PURE_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/dosbox-pure \
		$(LIBRETRO_CORE_DOSBOX_PURE_CROSS_OPTS) \
		platform=unix \
		CPUFLAGS="-DPAGESIZE=4096"
endef

define LIBRETRO_CORE_DOSBOX_PURE_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-dosbox-pure
	$(INSTALL) -m 0644 $(@D)/dosbox-pure/dosbox_pure_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-dosbox-pure/
	echo "dosbox_pure_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-dosbox-pure/.installed_so_name
endef

$(eval $(generic-package))
