################################################################################
#
# libretro-core-beetle-bsnes - SNES/Famicom (Mednafen bSNES, 소프트웨어 렌더링)
#
# 2026-07-16: 순수 소프트웨어 렌더러(GL 의존성 없음, 상류 Makefile 확인).
# TARGET_NAME은 저장소명(bsnes)과 다르게 mednafen_snes - 상류 Makefile 확인.
#
################################################################################

include $(BR2_EXTERNAL_C5_PANGUI_PATH)/package/libretro-core-organizer.mk
LIBRETRO_CORE_BEETLE_BSNES_SOURCE =

LIBRETRO_CORE_BEETLE_BSNES_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_BEETLE_BSNES_BUILD_CMDS
	test -d $(@D)/beetle-bsnes-libretro/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_BEETLE_BSNES_SITE) $(@D)/beetle-bsnes-libretro
	git -C $(@D)/beetle-bsnes-libretro checkout $(LIBRETRO_CORE_BEETLE_BSNES_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/beetle-bsnes-libretro \
		$(LIBRETRO_CORE_BEETLE_BSNES_CROSS_OPTS) \
		platform=unix
endef

define LIBRETRO_CORE_BEETLE_BSNES_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-beetle-bsnes
	$(INSTALL) -m 0644 $(@D)/beetle-bsnes-libretro/mednafen_snes_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-beetle-bsnes/
	echo "mednafen_snes_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-beetle-bsnes/.installed_so_name
endef

$(eval $(generic-package))
