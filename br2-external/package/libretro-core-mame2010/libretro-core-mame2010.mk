################################################################################
#
# libretro-core-mame2010 - MAME 0.139 (2010년 MAME 기준 아케이드 롬셋)
#
# 2026-07-19: arcade 시스템 3번째 코어로 추가 (fbneo -> mame2003-plus ->
# mame2010 순, 구형 롬셋 호환 범위를 넓히는 목적).
# platform=unix VRENDER=soft PTR64=1 ARM_ENABLED=0 FORCE_DRC_C_BACKEND=1
# 2026-07-19 시행착오 기록 (같은 "Relocations in generic ELF"/"file in
# wrong format" 에러가 4번 재발, 각 라운드마다 다른 가설을 배제하며 좁힘):
# 1차: ARM_ENABLED=1이 원인이라 추정 -> 0으로 바꿔도 동일 에러 재발.
# 2차: AR 미지정(unix 블록의 AR ?= @ar가 호스트 ar을 씀)이라 추정해서
#      AR/RANLIB 추가 -> 로그 확인 결과 ar 자체는 처음부터 aarch64-*-gcc-ar
#      로 정상 호출되고 있었음(진단 오류) - 여전히 동일 에러.
# 3차: DRC(동적 리컴파일러) 오브젝트가 원인이라 추정 - Makefile.common의
#      `ifndef FORCE_DRC_C_BACKEND` 블록이 PTR64 값과 무관하게 x86 전용
#      DRC 백엔드(drcbex64.o)를 끼워넣는 걸 발견하고 FORCE_DRC_C_BACKEND=1
#      추가 -> 컴파일 로그에서 NATIVE_DRC 매크로가 실제로 사라진 것까지
#      확인했지만 여전히 동일 에러 재발(진단은 맞았지만 원인이 하나 더 있었음).
# 진짜 원인(Makefile 직접 확인, 4차): 최종 링크 규칙
#   `$(EMULATOR): $(OBJECTS)` -> `$(CXX) $(LDFLAGS) ... -o $(TARGETLIB)`
#   이 makefile 어디에도 CXX 기본값이 없음(CC ?= g++만 있고 CXX는 없음) -
#   즉 컴파일은 우리가 지정한 크로스 CC를 쓰지만, 최종 링크는 make의
#   내장 기본값(시스템 PATH의 호스트 x86_64 g++)을 그대로 씀. 호스트
#   g++/ld로 aarch64 오브젝트를 링크하려다 "file in wrong format".
#   CXX="$(TARGET_CXX)"를 명시해서 해결.
#
################################################################################

include $(BR2_EXTERNAL_C5_PANGUI_PATH)/package/libretro-core-organizer.mk
LIBRETRO_CORE_MAME2010_SOURCE =

LIBRETRO_CORE_MAME2010_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
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
