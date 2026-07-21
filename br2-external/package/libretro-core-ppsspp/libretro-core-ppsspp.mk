################################################################################
#
# libretro-core-ppsspp - PlayStation Portable
# 서브모듈이 많은 대형 프로젝트(libretro 코어 빌드에 필요한 것만 초기화하면
# 이상적이지만, 어떤 서브모듈이 실제로 필요한지 사전 확인이 안 돼서
# 일단 전체(--recursive)로 받음 - 빌드 시간이 길 수 있음.
#
# 2026-07-12: platform 문자열에 "unix"가 있으면 if/else-if 체인에서 그 unix
# 분기가 먼저 매치되어 버려서 ARM64 전용 분기(정확한 aarch64 FFmpeg 경로,
# GLES 처리 포함)를 못 탐 - platform=arm64-gles로 "unix"를 빼고 "arm64"+
# "gles"만 넣어서 그 전용 분기를 직접 타게 함.
#
# 2026-07-14: libretro-cores.mk에서 분리(todo-20260712-libretro-cores-package-split).
# 빌드 커맨드는 원본과 동일(sed 패치 3건 포함, 무변경).
#
################################################################################

include $(BR2_EXTERNAL_C5_PANGUI_PATH)/package/libretro-core-organizer.mk
LIBRETRO_CORE_PPSSPP_SOURCE =
LIBRETRO_CORE_PPSSPP_DEPENDENCIES = mesa3d

LIBRETRO_CORE_PPSSPP_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_PPSSPP_BUILD_CMDS
	test -d $(@D)/ppsspp/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_PPSSPP_SITE) $(@D)/ppsspp
	git -C $(@D)/ppsspp checkout $(LIBRETRO_CORE_PPSSPP_VERSION)
	git -C $(@D)/ppsspp submodule update --init --recursive
	# Makefile.common의 "win32/darwin/android가 아니면 무조건 데스크탑
	# Linux(X11)"라는 기본 가정 때문에 COREFLAGS에 -DVK_USE_PLATFORM_XLIB_KHR가
	# 무조건 붙어서 X11/Xlib.h를 찾다가 크로스 빌드 실패함(우리 타겟은 X11
	# 자체가 없는 DRM/KMS 임베디드 환경). RetroArch가 자체 Vulkan 서페이스를
	# 제공하므로 이 코어에 XLIB 지원은 애초에 불필요 - 해당 줄만 제거.
	sed -i '/^COREFLAGS += -DVK_USE_PLATFORM_XLIB_KHR$$/d' \
		$(@D)/ppsspp/libretro/Makefile.common
	# 같은 이유로 "ifeq ($$(TARGET_ARCH),arm64)"가 안드로이드 전용
	# libadrenotools(Adreno GPU 드라이버 핫스왑용 안드로이드 링커 네임스페이스
	# 조작 코드, android/api-level.h 필요)를 일반 리눅스 aarch64에도 무조건
	# 끼워넣어서 크로스 빌드 실패함 - 우리는 안드로이드도 아니고 Adreno도
	# 아닌 Mali GPU라 이 코드 자체가 무관함. 해당 ifeq 블록만 통째로 제거
	# (같은 arm64 조건이라도 line 938의 "else ifeq" 블록은 실제 ARM64 JIT
	# 소스라 건드리면 안 됨 - 순수 "ifeq" 블록 하나만 유일하게 존재함).
	sed -i '/^ifeq ($$(TARGET_ARCH),arm64)$$/,/^endif$$/d' \
		$(@D)/ppsspp/libretro/Makefile.common
	# 세 번째 문제: 링크 단계에서 "undefined reference to
	# png_init_filter_functions_neon" 실패. 원인: libpng17의
	# arm/neon.h가 __aarch64__면 PNG_ARM_NEON_OPT를 2(런타임 체크 없이
	# NEON 코드 항상 사용)로 기본 설정하는데, 정작 그 구현체(arm/filter_neon.S)는
	# ".arch armv7-a" 32비트 전용 어셈블리라 Makefile.common이 TARGET_ARCH=arm64에는
	# 아예 안 끼워넣음(정상 - 애초에 aarch64용으로 못 씀) - 그 결과 aarch64에서
	# 헤더는 "NEON 있다"고 선언하는데 실제 구현은 빠지는 모순이 생김.
	# libpng 공식 문서(neon.h 주석)가 권장하는 대로 -DPNG_ARM_NEON_OPT=0을
	# COREFLAGS에 직접 추가해서 NEON 최적화 자체를 꺼버림(PNG 디코드는
	# PSP 에뮬레이터의 성능 핵심 경로가 아니라 손실 감수 가능).
	echo 'COREFLAGS += -DPNG_ARM_NEON_OPT=0' >> $(@D)/ppsspp/libretro/Makefile.common
	# 이전 시도(NEON 수정 전)에서 이미 컴파일된 ext/libpng17/*.o가 남아있으면
	# make가 COREFLAGS만 바뀐 걸로는 재컴파일 필요성을 못 느껴서(소스 .c
	# 자체는 안 바뀌었으니) 예전 플래그로 빌드된 stale .o를 그대로 재사용함 -
	# 방금 추가한 -DPNG_ARM_NEON_OPT=0이 실제로는 반영 안 된 채 링크되어 같은
	# 에러가 반복됨(실측: 이 줄 추가 전 재시도에서 확인). libpng17 .o만
	# 지워서 강제로 새 플래그로 재컴파일되게 함.
	find $(@D)/ppsspp/ext/libpng17 -name '*.o' -delete 2>/dev/null || true
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/ppsspp/libretro \
		$(LIBRETRO_CORE_PPSSPP_CROSS_OPTS) \
		platform=arm64-gles
endef

define LIBRETRO_CORE_PPSSPP_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-ppsspp
	$(INSTALL) -m 0644 $(@D)/ppsspp/libretro/ppsspp_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-ppsspp/
	echo "ppsspp_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-ppsspp/.installed_so_name
endef

$(eval $(generic-package))
