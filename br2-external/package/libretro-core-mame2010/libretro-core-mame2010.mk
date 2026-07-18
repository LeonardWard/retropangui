################################################################################
#
# libretro-core-mame2010 - MAME 0.139 (2010년 MAME 기준 아케이드 롬셋)
#
# 2026-07-19: arcade 시스템 3번째 코어로 추가 (fbneo -> mame2003-plus ->
# mame2010 순, 구형 롬셋 호환 범위를 넓히는 목적).
# platform=unix VRENDER=soft PTR64=1 ARM_ENABLED=0 - recalbox 원본은
# aarch64에도 ARM_ENABLED=1을 썼는데, 실제로 켜보니 ARM(32bit) 전용
# 어셈블리 CPU 코어가 aarch64 오브젝트와 링크 시 "Relocations in
# generic ELF" / "file in wrong format"으로 실패함(2026-07-19 확인) -
# recalbox 소스의 aarch64 분기가 실제로는 검증 안 된 죽은 코드였을
# 가능성. ARM_ENABLED=0(순수 C 코드 경로)으로 정정.
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
		platform=unix VRENDER=soft PTR64=1 ARM_ENABLED=0
endef

define LIBRETRO_CORE_MAME2010_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-mame2010
	$(INSTALL) -m 0644 $(@D)/mame2010/mame2010_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-mame2010/
	echo "mame2010_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-mame2010/.installed_so_name
endef

$(eval $(generic-package))
