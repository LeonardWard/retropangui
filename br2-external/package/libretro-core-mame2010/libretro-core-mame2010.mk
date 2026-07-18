################################################################################
#
# libretro-core-mame2010 - MAME 0.139 (2010년 MAME 기준 아케이드 롬셋)
#
# 2026-07-19: arcade 시스템 3번째 코어로 추가 (fbneo -> mame2003-plus ->
# mame2010 순, 구형 롬셋 호환 범위를 넓히는 목적).
# platform=unix + VRENDER=soft PTR64=1 ARM_ENABLED=1 - recalbox의
# libretro-mame2010.mk가 aarch64를 이 옵션 조합으로 명시적으로 처리함.
#
################################################################################

LIBRETRO_CORE_MAME2010_VERSION = 484456818393505dd4367e6e4c116c573c04a1ec
LIBRETRO_CORE_MAME2010_SITE = https://github.com/libretro/mame2010-libretro
LIBRETRO_CORE_MAME2010_SOURCE =

LIBRETRO_CORE_MAME2010_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	LD="$(TARGET_CXX)"

define LIBRETRO_CORE_MAME2010_BUILD_CMDS
	test -d $(@D)/mame2010/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_MAME2010_SITE) $(@D)/mame2010
	git -C $(@D)/mame2010 checkout $(LIBRETRO_CORE_MAME2010_VERSION)
	CFLAGS="$(TARGET_CFLAGS)" \
		CXXFLAGS="$(TARGET_CXXFLAGS)" \
		LDFLAGS="$(TARGET_LDFLAGS)" \
		$(MAKE) -C $(@D)/mame2010 \
		-f Makefile \
		$(LIBRETRO_CORE_MAME2010_CROSS_OPTS) \
		platform=unix VRENDER=soft PTR64=1 ARM_ENABLED=1
endef

define LIBRETRO_CORE_MAME2010_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-mame2010
	$(INSTALL) -m 0644 $(@D)/mame2010/mame2010_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-mame2010/
	echo "mame2010_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-mame2010/.installed_so_name
endef

$(eval $(generic-package))
