################################################################################
#
# libretro-core-beetle-saturn - Sega Saturn (Mednafen 기반, 소프트웨어 렌더링)
#
# 2026-07-14: libretro-cores.mk에서 분리(todo-20260712-libretro-cores-package-split).
# 빌드 커맨드는 원본과 동일.
#
################################################################################

LIBRETRO_CORE_BEETLE_SATURN_SOURCE =
LIBRETRO_CORE_BEETLE_SATURN_DEPENDENCIES = mesa3d

LIBRETRO_CORE_BEETLE_SATURN_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_BEETLE_SATURN_BUILD_CMDS
	test -d $(@D)/beetle-saturn-libretro/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_BEETLE_SATURN_SITE) $(@D)/beetle-saturn-libretro
	git -C $(@D)/beetle-saturn-libretro checkout $(LIBRETRO_CORE_BEETLE_SATURN_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/beetle-saturn-libretro \
		$(LIBRETRO_CORE_BEETLE_SATURN_CROSS_OPTS) \
		platform=$(LIBRETRO_CORE_BEETLE_SATURN_PLATFORM)
endef

define LIBRETRO_CORE_BEETLE_SATURN_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-beetle-saturn
	$(INSTALL) -m 0644 $(@D)/beetle-saturn-libretro/mednafen_saturn_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-beetle-saturn/
	echo "mednafen_saturn_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-beetle-saturn/.installed_so_name
endef

$(eval $(generic-package))
