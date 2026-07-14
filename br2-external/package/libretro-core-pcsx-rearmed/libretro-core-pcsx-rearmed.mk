################################################################################
#
# libretro-core-pcsx-rearmed - PlayStation 1
#
# 2026-07-14: libretro-cores.mk에서 분리(todo-20260712-libretro-cores-package-split).
# 빌드 커맨드는 원본과 동일.
#
################################################################################

LIBRETRO_CORE_PCSX_REARMED_VERSION = r26l
LIBRETRO_CORE_PCSX_REARMED_SITE = https://github.com/libretro/pcsx_rearmed
LIBRETRO_CORE_PCSX_REARMED_SOURCE =
LIBRETRO_CORE_PCSX_REARMED_DEPENDENCIES = mesa3d
LIBRETRO_CORE_PCSX_REARMED_LICENSE = GPL-2.0

LIBRETRO_CORE_PCSX_REARMED_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_PCSX_REARMED_BUILD_CMDS
	test -d $(@D)/pcsx_rearmed/.git || \
		git clone --filter=blob:none --branch $(LIBRETRO_CORE_PCSX_REARMED_VERSION) $(LIBRETRO_CORE_PCSX_REARMED_SITE) $(@D)/pcsx_rearmed
	git -C $(@D)/pcsx_rearmed checkout $(LIBRETRO_CORE_PCSX_REARMED_VERSION)
	git -C $(@D)/pcsx_rearmed submodule update --init
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/pcsx_rearmed \
		-f Makefile.libretro \
		$(LIBRETRO_CORE_PCSX_REARMED_CROSS_OPTS) \
		platform=unix
endef

define LIBRETRO_CORE_PCSX_REARMED_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-pcsx-rearmed
	$(INSTALL) -m 0644 $(@D)/pcsx_rearmed/pcsx_rearmed_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-pcsx-rearmed/
	echo "pcsx_rearmed_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-pcsx-rearmed/.installed_so_name
endef

$(eval $(generic-package))
