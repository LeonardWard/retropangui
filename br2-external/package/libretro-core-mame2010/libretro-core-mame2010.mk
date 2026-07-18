################################################################################
#
# libretro-core-mame2010 - MAME 0.139 (2010년 MAME 기준 아케이드 롬셋)
#
# 2026-07-19: arcade 시스템 3번째 코어로 추가 (fbneo -> mame2003-plus ->
# mame2010 순, 구형 롬셋 호환 범위를 넓히는 목적).
# platform=unix VRENDER=soft PTR64=1 ARM_ENABLED=0
# 2026-07-19 진짜 원인 확정: "Relocations in generic ELF"/"file in wrong
# format" 링크 에러는 ARM_ENABLED와 무관했음 - mame2010 Makefile의 unix
# 블록이 `AR ?= @ar`(AR을 안 넘기면 시스템 기본 ar, 즉 호스트 x86_64용
# ar을 그대로 씀)라서, 크로스 오브젝트를 호스트 ar로 아카이빙한 게 진짜
# 원인. CC/LD만 넘기고 AR/RANLIB을 빠뜨렸던 게 문제 - 다른 패키지
# (fbneo 등)는 picodrive 패턴을 따라 AR/RANLIB을 처음부터 넣었어서
# 이 문제가 없었음. ARM_ENABLED=0으로 되돌린 건 그대로 유지(안전한 쪽).
#
################################################################################

LIBRETRO_CORE_MAME2010_VERSION = 484456818393505dd4367e6e4c116c573c04a1ec
LIBRETRO_CORE_MAME2010_SITE = https://github.com/libretro/mame2010-libretro
LIBRETRO_CORE_MAME2010_SOURCE =

LIBRETRO_CORE_MAME2010_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	LD="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)"

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
