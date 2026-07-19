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
# NOASM=1 (2026-07-19 확인): NOASM은 UNAME(빌드 호스트) 기반 aarch64
# 자동감지 블록 안에서만 켜지는데 크로스컴파일 환경에서는 그 블록이 안
# 타서 꺼진 채로 남음. eminline.h가 "no matching assembler
# implementations found - please compile with NOASM=1" 컴파일 에러.
# 명시적으로 NOASM=1을 넘겨 순수 C 폴백 경로 사용.
#
# genie가 만든 프로젝트 .make 파일들에서 -m64를 sed로 제거해야 함
# (2026-07-19, ARCHITECTURE 강제를 시도했다가 되돌린 시행착오 포함):
# 처음엔 ARCHITECTURE=(빈 값)으로 -m64 문제를 피하려 했으나, genie가
# 만드는 config 이름이 libretro32/libretro64뿐이라 접미사 없는
# config=libretro는 아예 매치가 안 되고, 그러면 PTR64=1 매크로 자체가
# 안 붙어서 "static assertion failed: PTR64 flag not enabled" 에러로
# 이어짐(emu.make 848번째 줄 config=libretro64 블록에 PTR64=1은 있지만
# -m64도 같이 하드코딩돼 있음 - genie/premake가 "64bit=x86_64"를
# 전제하는 게 진짜 근본 원인). genie가 그 config을 만들어낸 직후 -m64
# 문자열만 모든 .make 파일에서 제거하는 방식으로 전환. genie가 만드는
# 산출물(빌드 시점 생성 파일)을 조정하는 것이라 업스트림 소스 패치가
# 아님([[feedback_no_core_patching]] 저촉 아님) - 매 빌드마다 재생성
# 되고 우리 .mk 안에서만 처리됨.
#
# PTR64는 명시적으로 넘기지 않음 (2026-07-19, 공식 자료 확인 후 정정):
# 여러 라운드 시행착오 끝에 libretro/mame2016-libretro의 공식
# Makefile.libretro(래퍼)를 직접 확인함 - 주석에 "You probably
# shouldn't need to set this anymore"라고 명시돼 있고 PLATFLAGS 로직도
# PTR64가 비어있으면 아예 안 넘김. 우리가 강제로 PTR64=1을 넘긴 게
# 오히려 config=libretro(접미사 없음, genie 목록에 없음) 매치 실패의
# 원인이었을 가능성. PTR64를 안 넘기면 UNAME 기반 자동감지가 "빌드
# 호스트가 x86_64"라는 사실을 그대로 반영해 ARCHITECTURE=_x64로
# 자동 설정되고, 이게 config=libretro64(존재하는 config, PTR64=1
# 매크로 포함)와 정확히 매치됨 - 크로스컴파일 환경에서 결과적으로
# "우연히" 맞아떨어지는 것이지만 재현 가능한 동작.
# ARCH="" 추가: Makefile.libretro가 명시하는 패턴(ARCH는 Apple 전용
# 변수라 libretro 쪽 의미와 충돌 - 항상 빈 값으로 지정해야 함).
#
# 참고로 이 코어 저장소의 공식 CI(.travis.yml)는 x86_64 Linux/OSX만
# 검증하고 있어(2016년 Travis 설정, gcc-5) aarch64 크로스컴파일은
# 업스트림이 한 번도 공식 검증한 적 없는 영역 - 시행착오가 많았던 이유.
#
################################################################################

LIBRETRO_CORE_MAME2016_VERSION = 3529f4e2cb8e74c88d83bc9fc9d695f78dc9a975
LIBRETRO_CORE_MAME2016_SITE = https://github.com/libretro/mame2016-libretro
LIBRETRO_CORE_MAME2016_SOURCE =

LIBRETRO_CORE_MAME2016_OPTS = \
	platform="unix" \
	ARCH="" \
	LIBRETRO_CPU="$(BR2_ARCH)" \
	LIBRETRO_OS="unix" \
	CONFIG="libretro" \
	OSD="retro" \
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
	$(MAKE) -C $(@D)/mame2016 -f makefile $(LIBRETRO_CORE_MAME2016_OPTS) \
		build/projects/retro/mamearcade/gmake-linux/Makefile
	find $(@D)/mame2016/build/projects -name '*.make' -exec \
		sed -i 's/-m64//g' {} +
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
