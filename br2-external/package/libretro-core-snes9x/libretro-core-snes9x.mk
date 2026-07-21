################################################################################
#
# libretro-core-snes9x - SNES
#
# 2026-07-14: libretro-cores.mk에서 분리(todo-20260712-libretro-cores-package-split).
# 빌드 커맨드는 원본과 동일.
#
################################################################################

LIBRETRO_CORE_SNES9X_SOURCE =
LIBRETRO_CORE_SNES9X_DEPENDENCIES = mesa3d
LIBRETRO_CORE_SNES9X_LICENSE = GPL-2.0

LIBRETRO_CORE_SNES9X_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_SNES9X_BUILD_CMDS
	test -d $(@D)/snes9x/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_SNES9X_SITE) $(@D)/snes9x
	git -C $(@D)/snes9x checkout $(LIBRETRO_CORE_SNES9X_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/snes9x/libretro \
		$(LIBRETRO_CORE_SNES9X_CROSS_OPTS) \
		platform=unix
endef

define LIBRETRO_CORE_SNES9X_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-snes9x
	$(INSTALL) -m 0644 $(@D)/snes9x/libretro/snes9x_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-snes9x/
	echo "snes9x_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-snes9x/.installed_so_name
endef

$(eval $(generic-package))
