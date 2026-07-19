################################################################################
#
# libretro-core-mame2016 - MAME 0.174 (2016년 MAME 기준 아케이드 롬셋)
#
# 2026-07-19: arcade 시스템 4번째 코어로 추가.
# genie/premake 기반 빌드 시스템(재귀적으로 자체 빌드툴을 먼저 native로
# 빌드한 뒤 실제 컴파일 makefile을 생성) - fbneo/mame2003-plus/mame2010보다
# 훨씬 무겁고 실패 가능성도 높음. recalbox의 예전 mk는 PYTHON_EXECUTABLE=python2
# 를 썼지만 이 프로젝트 buildroot엔 host-python2가 없음(buildroot 2024.02.1
# 자체가 python2 패키지를 지원 안 함) - 최신 업스트림 makefile을 직접 확인해
# python3도 지원됨을 확인하고 python3로 지정.
# PTR64=1(aarch64=64bit), LIBRETRO_CPU/OS는 buildroot 표준 변수 그대로 전달.
# FORCE_DRC_C_BACKEND=1: mame2010에서 이 옵션 없이 PTR64=1만 넘겼다가
# x86 전용 동적 리컴파일러(drcbex64.o)가 무조건 끼어들어 "Relocations in
# generic ELF"/"file in wrong format" 링크 에러가 난 것을 미리 겪어서
# (todo-core-lr-mame2010.html 참고) mame2016도 선제적으로 추가.
#
# host 전용 빌드 도구를 먼저 host 네이티브로 만들어야 함 (2026-07-19 확인):
# genie(빌드 프로젝트 생성기)와 m68kops.cpp(옵코드 테이블, m68kmake로 생성)
# 둘 다 makefile이 재귀 서브메이크에 부모의 CC/CXX를 그대로 넘기도록
# 하드코딩돼 있어서, 상위에서 크로스 CC를 지정하면 이 host 도구들까지
# aarch64로 컴파일되어 실행 자체가 안 됨("Syntax error" - 셸이 ELF를
# 텍스트로 읽으려다 실패). 크로스 CC 없이 이 두 타겟만 먼저 만들어두면
# (host x86_64로 정상 생성) 본 빌드에서는 mtime이 최신이라 재생성 안
# 되고 그대로 쓰임 - genie는 실행파일, m68kops.cpp는 텍스트 소스라
# 아키텍처 무관하게 안전.
#
# ARCHITECTURE= (빈 값, 2026-07-19 확인): 이 makefile은 PTR64=1이면
# 무조건 ARCHITECTURE := _x64(x86_64)로 단정함("64bit=x86_64"라는 잘못된
# 가정) - aarch64 예외 처리가 있긴 하지만 UNAME=$(shell uname -a)로
# "빌드를 실행하는 호스트"를 감지하는 방식이라 크로스컴파일 환경(x86_64
# 컨테이너 위에서 aarch64를 타겟팅)에서는 항상 빗나감. 그 결과 최종 make
# 타겟이 linux_x64가 되어 -m64(x86 전용 GCC 옵션)를 aarch64 GCC에 넘겨
# "unrecognized command-line option" 실패. ARCHITECTURE를 커맨드라인에서
# 빈 값으로 강제하면(커맨드라인 변수가 makefile 내부 := 할당을 항상
# 이김) 최종 타겟이 linux(아키텍처 접미사 없는 기본 config)가 되어 문제
# 회피.
#
# NOASM=1 (2026-07-19 확인): ARCHITECTURE와 정확히 같은 뿌리의 문제 -
# NOASM도 같은 UNAME(호스트) 기반 aarch64 감지 블록 안에서만 자동
# 설정되는데 크로스컴파일 환경에서는 그 블록이 안 타서 NOASM이 꺼진
# 채로 남음. 그 결과 eminline.h가 x86/ARM32용 인라인 어셈 매크로를
# 찾다가 "no matching assembler implementations found - please compile
# with NOASM=1" 컴파일 에러. 명시적으로 NOASM=1을 넘겨 순수 C 폴백
# 경로를 쓰도록 강제.
#
################################################################################

LIBRETRO_CORE_MAME2016_VERSION = 3529f4e2cb8e74c88d83bc9fc9d695f78dc9a975
LIBRETRO_CORE_MAME2016_SITE = https://github.com/libretro/mame2016-libretro
LIBRETRO_CORE_MAME2016_SOURCE =

LIBRETRO_CORE_MAME2016_OPTS = \
	platform="unix" \
	LIBRETRO_CPU="$(BR2_ARCH)" \
	LIBRETRO_OS="unix" \
	CONFIG="libretro" \
	OSD="retro" \
	PTR64=1 \
	ARCHITECTURE= \
	NOASM=1 \
	FORCE_DRC_C_BACKEND=1 \
	PYTHON_EXECUTABLE=python3 \
	NOWERROR=1 \
	VERBOSE=1 \
	SUBTARGET=arcade

define LIBRETRO_CORE_MAME2016_BUILD_CMDS
	test -d $(@D)/mame2016/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_MAME2016_SITE) $(@D)/mame2016
	git -C $(@D)/mame2016 checkout $(LIBRETRO_CORE_MAME2016_VERSION)
	mkdir -p $(@D)/mame2016/build/gmake/libretro/obj/x64/libretro/src/osd/retro
	mkdir -p $(@D)/mame2016/3rdparty/genie/build/gmake.linux/obj/Release/src/host
	$(MAKE) -C $(@D)/mame2016 -f makefile $(LIBRETRO_CORE_MAME2016_OPTS) \
		3rdparty/genie/bin/linux/genie
	$(MAKE) -C $(@D)/mame2016 -f makefile $(LIBRETRO_CORE_MAME2016_OPTS) \
		src/devices/cpu/m68000/m68kops.cpp
	$(MAKE) CXX="$(TARGET_CXX)" CC="$(TARGET_CC)" LD="$(TARGET_LD)" \
		RANLIB="$(TARGET_RANLIB)" AR="$(TARGET_CC)-ar" \
		-C $(@D)/mame2016 -f makefile $(LIBRETRO_CORE_MAME2016_OPTS)
endef

define LIBRETRO_CORE_MAME2016_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-mame2016
	$(INSTALL) -m 0644 $(@D)/mame2016/mamearcade2016_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-mame2016/mame2016_libretro.so
	echo "mame2016_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-mame2016/.installed_so_name
endef

$(eval $(generic-package))
