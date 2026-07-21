################################################################################
#
# libretro-core-picodrive - Sega Mega Drive / Genesis / 32X / Mega-CD
#
# 2026-07-14: libretro-cores.mk에서 분리(todo-20260712-libretro-cores-package-split).
# 빌드 커맨드는 원본과 동일.
#
################################################################################

include $(BR2_EXTERNAL_C5_PANGUI_PATH)/package/libretro-core-organizer.mk
LIBRETRO_CORE_PICODRIVE_SOURCE =
LIBRETRO_CORE_PICODRIVE_DEPENDENCIES = mesa3d

LIBRETRO_CORE_PICODRIVE_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_PICODRIVE_BUILD_CMDS
	test -d $(@D)/picodrive/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_PICODRIVE_SITE) $(@D)/picodrive
	git -C $(@D)/picodrive checkout $(LIBRETRO_CORE_PICODRIVE_VERSION)
	git -C $(@D)/picodrive submodule update --init
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/picodrive \
		-f Makefile.libretro \
		$(LIBRETRO_CORE_PICODRIVE_CROSS_OPTS) \
		platform=unix
endef

define LIBRETRO_CORE_PICODRIVE_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-picodrive
	$(INSTALL) -m 0644 $(@D)/picodrive/picodrive_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-picodrive/
	echo "picodrive_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-picodrive/.installed_so_name
endef

$(eval $(generic-package))
