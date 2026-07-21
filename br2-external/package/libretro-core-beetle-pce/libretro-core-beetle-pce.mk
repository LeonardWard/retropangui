################################################################################
#
# libretro-core-beetle-pce - PC Engine/TurboGrafx-16 (Mednafen 기반, 소프트웨어 렌더링)
#
# 2026-07-16: 순수 소프트웨어 렌더러(GL 의존성 없음, 상류 Makefile 확인) -
# beetle-saturn과 동일한 빌드 패턴, mesa3d DEPENDENCIES만 뺌.
#
################################################################################

LIBRETRO_CORE_BEETLE_PCE_SOURCE =

LIBRETRO_CORE_BEETLE_PCE_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_BEETLE_PCE_BUILD_CMDS
	test -d $(@D)/beetle-pce-libretro/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_BEETLE_PCE_SITE) $(@D)/beetle-pce-libretro
	git -C $(@D)/beetle-pce-libretro checkout $(LIBRETRO_CORE_BEETLE_PCE_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/beetle-pce-libretro \
		$(LIBRETRO_CORE_BEETLE_PCE_CROSS_OPTS) \
		platform=$(LIBRETRO_CORE_BEETLE_PCE_PLATFORM)
endef

define LIBRETRO_CORE_BEETLE_PCE_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-beetle-pce
	$(INSTALL) -m 0644 $(@D)/beetle-pce-libretro/mednafen_pce_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-beetle-pce/
	echo "mednafen_pce_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-beetle-pce/.installed_so_name
endef

$(eval $(generic-package))
