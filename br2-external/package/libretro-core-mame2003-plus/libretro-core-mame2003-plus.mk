################################################################################
#
# libretro-core-mame2003-plus - MAME 2003-Plus (구형 아케이드 롬셋)
#
# 2026-07-19: lr-fbneo와 함께 arcade 시스템 2번째 코어로 추가.
# platform=unix로 빌드 - batocera libretro-mame2003-plus.mk가 aarch64를
# 명시적으로 "unix"로 매핑하고 있어(HAS_CYCLONE/HAS_DRZ80 같은 특수 옵션은
# s812/rpi2 등 32bit 저사양 SoC 전용) 이 프로젝트(odroidc5, aarch64)엔
# 해당 안 됨.
# obj/mame/cpu/ccpu 디렉토리를 빌드 전에 미리 만들어야 함(batocera/recalbox
# 둘 다 공통으로 하는 걸 보면 Makefile이 자동 생성 안 해주는 것으로 보임).
#
################################################################################

LIBRETRO_CORE_MAME2003_PLUS_SOURCE =

LIBRETRO_CORE_MAME2003_PLUS_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)"

define LIBRETRO_CORE_MAME2003_PLUS_BUILD_CMDS
	test -d $(@D)/mame2003-plus/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_MAME2003_PLUS_SITE) $(@D)/mame2003-plus
	git -C $(@D)/mame2003-plus checkout $(LIBRETRO_CORE_MAME2003_PLUS_VERSION)
	mkdir -p $(@D)/mame2003-plus/obj/mame/cpu/ccpu
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/mame2003-plus \
		-f Makefile \
		$(LIBRETRO_CORE_MAME2003_PLUS_CROSS_OPTS) \
		platform=$(LIBRETRO_CORE_MAME2003_PLUS_PLATFORM)
endef

define LIBRETRO_CORE_MAME2003_PLUS_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-mame2003-plus
	$(INSTALL) -m 0644 $(@D)/mame2003-plus/mame2003_plus_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-mame2003-plus/
	echo "mame2003_plus_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-mame2003-plus/.installed_so_name
endef

$(eval $(generic-package))
