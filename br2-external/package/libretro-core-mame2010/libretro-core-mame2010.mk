################################################################################
#
# libretro-core-mame2010 - MAME 0.139 (2010년 MAME 기준 아케이드 롬셋)
#
# 2026-07-19: arcade 시스템 3번째 코어로 추가 (fbneo -> mame2003-plus ->
# mame2010 순, 구형 롬셋 호환 범위를 넓히는 목적).
# platform=unix VRENDER=soft PTR64=1 ARM_ENABLED=0 FORCE_DRC_C_BACKEND=1
# 2026-07-19 시행착오 기록:
# 1차: ARM_ENABLED=1이 원인이라 추정 -> 0으로 바꿔도 동일 에러 재발.
# 2차: AR 미지정(unix 블록의 AR ?= @ar가 호스트 ar을 씀)이라 추정해서
#      AR/RANLIB 추가 -> 여전히 동일 에러("Relocations in generic ELF"/
#      "file in wrong format"). ar 자체는 aarch64-*-gcc-ar로 정상 호출됨
#      을 로그로 확인, AR 문제가 아니었음.
# 진짜 원인(Makefile.common 확인): m68kcpu.o가 걸리는 링크 에러는 DRC
# (동적 리컴파일러) 오브젝트 때문 - `ifndef FORCE_DRC_C_BACKEND` 블록이
# PTR64 값과 무관하게 무조건 x86 전용 DRC 백엔드(drcbex64.o, x86 어셈블리
# 포함)를 링크에 끼워넣고 NATIVE_DRC=drcbe_x64_be_interface를 정의함 -
# 소스 주석에 "fixme - need to make this work for other target
# architectures (PPC)"라고 명시돼 있어 x86 이외 아키텍처를 원래 지원 안
# 함. wiiu/classic_armv8_a35 등 비x86 플랫폼은 전부 FORCE_DRC_C_BACKEND=1
# (아키텍처 무관 순수 C DRC 백엔드)을 씀 - 같은 방식으로 정정.
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
		platform=unix VRENDER=soft PTR64=1 ARM_ENABLED=0 FORCE_DRC_C_BACKEND=1
endef

define LIBRETRO_CORE_MAME2010_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-mame2010
	$(INSTALL) -m 0644 $(@D)/mame2010/mame2010_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-mame2010/
	echo "mame2010_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-mame2010/.installed_so_name
endef

$(eval $(generic-package))
