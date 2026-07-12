################################################################################
#
# libretro-cores - NES, SNES, PSX, MD, DOS, ScummVM, Saturn, N64, PSP libretro cores for RetroArch
#
# 버전 관리:
#   fceumm          : 커밋 c0c52ad0 (2026-06, libretro/libretro-fceumm, FDS BIOS 불필요)
#   nestopia        : 커밋 b0fd87dd (2024-01, libretro/nestopia, 별도 릴리즈 태그 없음)
#   snes9x          : 커밋 e755ae51 (2025-04, libretro/snes9x, 별도 릴리즈 태그 없음)
#   pcsx_rearmed    : 릴리즈 태그 r26l (libretro/pcsx_rearmed)
#   beetle_psx_hw   : 커밋 d460f834 (2026-06, libretro/beetle-psx-libretro, Vulkan HW 전용 — GL 제외)
#   picodrive       : 커밋 f0d4a011 (2026-06, libretro/picodrive, 메가드라이브/32X/MCD)
#   bluemsx         : 커밋 b76f2795 (2026-06, libretro/bluemsx-libretro, MSX/MSX2/MSX2+/turboR)
#   dosbox_pure     : 커밋 f587236b (2025-04, schellingb/dosbox-pure, 별도 릴리즈 태그 없음)
#   scummvm         : 릴리즈 태그 libretro-v3.1.0.1 (libretro/scummvm)
#   quasi88         : 커밋 520e0a37 (2026-06, libretro/quasi88-libretro, PC-88)
#   np2kai          : 커밋 54ec39f5 (2026-06, libretro/np2kai, PC-98)
#   beetle_saturn   : 커밋 6f0cb9d1 (2026-07, libretro/beetle-saturn-libretro, 소프트웨어 렌더링 - HW(GL) 가속 코어 kronos는
#                     2026-07-12 조사 시점에 독립 공개 저장소를 못 찾아서 제외)
#   mupen64plus_next: 커밋 98c1b0d8 (2026-07, libretro/mupen64plus-libretro-nx, develop 브랜치)
#   parallel_n64    : 커밋 1a68b3bd (2026-07, libretro/parallel-n64, GLideN64 렌더러 - N64 대체 코어)
#   ppsspp          : 커밋 f0baf3ad (2026-07, hrydgard/ppsspp, 서브모듈 23개 --recursive로 받음 - 빌드 시간 김)
#
#   kronos          : 커밋 146f4295 (2026-07, libretro/yabause, Saturn GL 가속 - beetle_saturn과 별개 코어).
#                     Batocera가 Odroid C4(S905X3, 이 프로젝트의 C5와 같은 칩 계열)용으로 검증해둔
#                     platform="odroid-c4" FORCE_GLES=1 레시피를 그대로 따름 - mesa3d(빌드 타임 헤더용,
#                     이미 defconfig에 있음)+mali-ddk(런타임 libEGL/libGLESv2 - 이미 있음) 조합 확인함.
#
# 2026-07-12: 게임큐브(dolphin) 코어는 이 파일에 없음 - libretro/dolphin은 다른 코어들과
# 달리 Makefile.libretro 방식이 아니라 데스크톱 Dolphin 프로젝트 그대로 CMakeLists.txt +
# .gitmodules(Externals) 기반의 완전히 다른 빌드 체계라, 이 파일의 generic-package 패턴이
# 아니라 kodi-pangui처럼 별도 cmake-package로 새로 만들어야 함 - 훨씬 큰 작업이라 별도로
# 진행 여부를 확인받기로 함(아래 참고).
#
# 빌드 방식:
#   libretro 코어 Makefile은 크로스컴파일러 툴체인만 받고
#   CFLAGS/-fPIC/LD 등은 자체적으로 처리하도록 설계되어 있음.
#   TARGET_CONFIGURE_OPTS는 CFLAGS/CXXFLAGS/LD를 커맨드라인 변수로
#   넘겨 Makefile 내부 설정을 덮어쓰므로 사용하지 않음.
#   대신 크로스컴파일러 변수만 전달하는 LIBRETRO_CROSS_OPTS 사용.
#
################################################################################

LIBRETRO_CORES_VERSION = 1.0
LIBRETRO_CORES_LICENSE = GPL-2.0 (nestopia, snes9x, pcsx_rearmed, dosbox_pure, scummvm)
# 자체 git clone으로 다운로드하므로 Buildroot 자동 소스 다운로드 비활성화
LIBRETRO_CORES_SOURCE =
# kronos(Saturn GL 가속)가 빌드 타임에 EGL/GLES2 헤더를 필요로 함
LIBRETRO_CORES_DEPENDENCIES += mesa3d

CORES_INSTALL_DIR = $(TARGET_DIR)/usr/lib/libretro

# libretro 코어용 크로스컴파일 변수 (툴체인만, CFLAGS/CXXFLAGS/LD 제외)
LIBRETRO_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

################################################################################
# fceumm - NES/Famicom/FDS (BIOS 불필요, FDS 내장 에뮬레이션 지원)
################################################################################

FCEUMM_SITE = https://github.com/libretro/libretro-fceumm
FCEUMM_VERSION = c0c52ad0eb36cdbfc66e9bdb72efc83103e85e22

define LIBRETRO_CORES_BUILD_FCEUMM
	test -d $(@D)/libretro-fceumm/.git || \
		git clone --filter=blob:none $(FCEUMM_SITE) $(@D)/libretro-fceumm
	git -C $(@D)/libretro-fceumm checkout $(FCEUMM_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/libretro-fceumm \
		-f Makefile.libretro \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix
endef

################################################################################
# nestopia - NES/Famicom
################################################################################

NESTOPIA_SITE = https://github.com/libretro/nestopia
NESTOPIA_VERSION = b0fd87dd07e3c52903435d302b04e5e97796f127

define LIBRETRO_CORES_BUILD_NESTOPIA
	test -d $(@D)/nestopia/.git || \
		git clone --filter=blob:none $(NESTOPIA_SITE) $(@D)/nestopia
	git -C $(@D)/nestopia checkout $(NESTOPIA_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/nestopia/libretro \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix
endef

################################################################################
# snes9x - SNES
################################################################################

SNES9X_SITE = https://github.com/libretro/snes9x
SNES9X_VERSION = e755ae51b61f49e4ac48bdeaa16e3c72e70db0e5

define LIBRETRO_CORES_BUILD_SNES9X
	test -d $(@D)/snes9x/.git || \
		git clone --filter=blob:none $(SNES9X_SITE) $(@D)/snes9x
	git -C $(@D)/snes9x checkout $(SNES9X_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/snes9x/libretro \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix
endef

################################################################################
# pcsx_rearmed - PlayStation 1
################################################################################

PCSX_SITE = https://github.com/libretro/pcsx_rearmed
PCSX_VERSION = r26l

define LIBRETRO_CORES_BUILD_PCSX
	test -d $(@D)/pcsx_rearmed/.git || \
		git clone --filter=blob:none --branch $(PCSX_VERSION) $(PCSX_SITE) $(@D)/pcsx_rearmed
	git -C $(@D)/pcsx_rearmed checkout $(PCSX_VERSION)
	git -C $(@D)/pcsx_rearmed submodule update --init
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/pcsx_rearmed \
		-f Makefile.libretro \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix
endef

################################################################################
# beetle-psx-hw - PlayStation 1 (Vulkan HW renderer, desktop OpenGL 제외)
# HAVE_VULKAN=1 단독 사용: Vulkan만 활성화, HAVE_OPENGL은 0 유지
# Mali Valhall(r44p0)은 Vulkan을 지원하므로 HW 가속 가능
################################################################################

BEETLE_PSX_HW_SITE = https://github.com/libretro/beetle-psx-libretro
BEETLE_PSX_HW_VERSION = d460f8342060526678e7fd8222048324c2a80d86

define LIBRETRO_CORES_BUILD_BEETLE_PSX_HW
	test -d $(@D)/beetle-psx-libretro/.git || \
		git clone --filter=blob:none $(BEETLE_PSX_HW_SITE) $(@D)/beetle-psx-libretro
	git -C $(@D)/beetle-psx-libretro checkout $(BEETLE_PSX_HW_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/beetle-psx-libretro \
		$(LIBRETRO_CROSS_OPTS) \
		HAVE_VULKAN=1 \
		HAVE_OPENGL=0 \
		LINK_STATIC_LIBCPLUSPLUS=0 \
		platform=unix
endef

################################################################################
# picodrive - Sega Mega Drive / Genesis / 32X / Mega-CD
################################################################################

PICODRIVE_SITE = https://github.com/libretro/picodrive
PICODRIVE_VERSION = f0d4a0118a9733a1f10bce5a4ac772c474f9300d

define LIBRETRO_CORES_BUILD_PICODRIVE
	test -d $(@D)/picodrive/.git || \
		git clone --filter=blob:none $(PICODRIVE_SITE) $(@D)/picodrive
	git -C $(@D)/picodrive checkout $(PICODRIVE_VERSION)
	git -C $(@D)/picodrive submodule update --init
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/picodrive \
		-f Makefile.libretro \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix
endef

################################################################################
# blueMSX - MSX / MSX2 / MSX2+ / MSX turbo R
################################################################################

BLUEMSX_SITE = https://github.com/libretro/bluemsx-libretro
BLUEMSX_VERSION = b76f27959a32e18aa04c619273152178fd0cf03b

define LIBRETRO_CORES_BUILD_BLUEMSX
	test -d $(@D)/bluemsx-libretro/.git || \
		git clone --filter=blob:none $(BLUEMSX_SITE) $(@D)/bluemsx-libretro
	git -C $(@D)/bluemsx-libretro checkout $(BLUEMSX_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/bluemsx-libretro \
		-f Makefile.libretro \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix
endef

################################################################################
# dosbox-pure - DOS
################################################################################

DOSBOX_PURE_SITE = https://github.com/schellingb/dosbox-pure
DOSBOX_PURE_VERSION = f587236b2d016f4f16d672e9ce2829bdf507bf9b

define LIBRETRO_CORES_BUILD_DOSBOX_PURE
	test -d $(@D)/dosbox-pure/.git || \
		git clone --filter=blob:none $(DOSBOX_PURE_SITE) $(@D)/dosbox-pure
	git -C $(@D)/dosbox-pure checkout $(DOSBOX_PURE_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/dosbox-pure \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix \
		CPUFLAGS="-DPAGESIZE=4096"
endef

################################################################################
# scummvm - Point-and-click adventures
################################################################################

SCUMMVM_SITE = https://github.com/libretro/scummvm
SCUMMVM_VERSION = libretro-v3.1.0.1
# configure_submodules.sh가 의존하는 두 서브레포
SCUMMVM_DEPS_PATH = $(@D)/scummvm/backends/platform/libretro/deps
LIBRETRO_DEPS_URL    = https://github.com/libretro/libretro-deps
LIBRETRO_DEPS_COMMIT = 7e6e34f0319f4c7448d72f0e949e76265ccf55a1
LIBRETRO_COMMON_URL    = https://github.com/libretro/libretro-common
LIBRETRO_COMMON_COMMIT = 70ed90c42ddea828f53dd1b984c6443ddb39dbd6

define LIBRETRO_CORES_BUILD_SCUMMVM
	test -d $(@D)/scummvm/.git || \
		git clone --filter=blob:none $(SCUMMVM_SITE) $(@D)/scummvm
	git -C $(@D)/scummvm checkout $(SCUMMVM_VERSION)
	mkdir -p $(SCUMMVM_DEPS_PATH)
	# libretro-deps: configure_submodules.sh는 commit hash fetch로 실패하므로 직접 클론
	test -f $(SCUMMVM_DEPS_PATH)/libretro-deps/Makefile || \
		(rm -rf $(SCUMMVM_DEPS_PATH)/libretro-deps && \
		 git clone --filter=blob:none $(LIBRETRO_DEPS_URL) $(SCUMMVM_DEPS_PATH)/libretro-deps && \
		 git -C $(SCUMMVM_DEPS_PATH)/libretro-deps checkout $(LIBRETRO_DEPS_COMMIT))
	# libretro-common: 동일
	test -f $(SCUMMVM_DEPS_PATH)/libretro-common/README.md || \
		(rm -rf $(SCUMMVM_DEPS_PATH)/libretro-common && \
		 git clone --filter=blob:none $(LIBRETRO_COMMON_URL) $(SCUMMVM_DEPS_PATH)/libretro-common && \
		 git -C $(SCUMMVM_DEPS_PATH)/libretro-common checkout $(LIBRETRO_COMMON_COMMIT))
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/scummvm/backends/platform/libretro \
		CC="$(TARGET_CC)" \
		CXX="$(TARGET_CXX)" \
		AR="$(TARGET_AR) cru" \
		RANLIB="$(TARGET_RANLIB)" \
		STRIP="$(TARGET_STRIP)" \
		OBJCOPY="$(TARGET_OBJCOPY)" \
		platform=unix \
		BUILD_64BIT=1
endef

################################################################################
# quasi88 - PC-88
################################################################################

QUASI88_SITE = https://github.com/libretro/quasi88-libretro
QUASI88_VERSION = 520e0a37ac0e9cf8b0536fe83fda3aacc9ba73bb

define LIBRETRO_CORES_BUILD_QUASI88
	test -d $(@D)/quasi88-libretro/.git || \
		git clone --filter=blob:none $(QUASI88_SITE) $(@D)/quasi88-libretro
	git -C $(@D)/quasi88-libretro checkout $(QUASI88_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/quasi88-libretro \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix
endef

################################################################################
# np2kai - PC-98
################################################################################

NP2KAI_SITE = https://github.com/libretro/np2kai
NP2KAI_VERSION = 54ec39f50d197cc02909cd4fd2a8591bb38651b0

define LIBRETRO_CORES_BUILD_NP2KAI
	test -d $(@D)/np2kai/.git || \
		git clone --filter=blob:none $(NP2KAI_SITE) $(@D)/np2kai
	git -C $(@D)/np2kai checkout $(NP2KAI_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/np2kai/sdl \
		-f Makefile.libretro \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix
endef

################################################################################
# beetle_saturn - Sega Saturn (Mednafen 기반, 소프트웨어 렌더링)
################################################################################

BEETLE_SATURN_SITE = https://github.com/libretro/beetle-saturn-libretro
BEETLE_SATURN_VERSION = 6f0cb9d1b9689601cd7dbf08e992d232304f50f7

define LIBRETRO_CORES_BUILD_BEETLE_SATURN
	test -d $(@D)/beetle-saturn-libretro/.git || \
		git clone --filter=blob:none $(BEETLE_SATURN_SITE) $(@D)/beetle-saturn-libretro
	git -C $(@D)/beetle-saturn-libretro checkout $(BEETLE_SATURN_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/beetle-saturn-libretro \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix
endef

################################################################################
# mupen64plus_next - Nintendo 64
#
# 2026-07-12: 첫 빌드 시도에서 "-msse -msse2 unrecognized" 에러로 실패 -
# Makefile이 ARCH 미지정 시 `uname -m`으로 자동감지하는데, 이게 크로스
# 컴파일 빌드 호스트(x86_64 Docker)를 가리켜서 x86_64 SSE 플래그가
# 타겟(aarch64) 컴파일러에 그대로 넘어감. ARCH=aarch64로 명시해서 우회
# (parallel_n64도 같은 패턴, ppsspp는 platform 문자열 자체에 arm64를
# 넣어야 하는 다른 방식 - 아래 참고).
#
# 2026-07-12 (2차): ARCH 수정 후 재시도에서 "GL/gl.h: No such file or
# directory"로 다시 실패 - platform=unix 기본값이 데스크탑 OpenGL
# (GLideN64 렌더러가 GL/gl.h를 include)을 가정하는데, C5는 Mali GPU라
# GLES2/3만 제공함(mesa3d는 빌드타임 헤더용, 런타임은 libMali.so).
# FORCE_GLES=1을 넘겨서 GLESv2로 링크하도록 강제(parallel_n64도 동일 -
# 둘 다 GLideN64 기반 렌더러라 같은 문제를 공유함).
################################################################################

MUPEN64PLUS_NEXT_SITE = https://github.com/libretro/mupen64plus-libretro-nx
MUPEN64PLUS_NEXT_VERSION = 98c1b0d877542b01314b3b04272282ba223b65b3

define LIBRETRO_CORES_BUILD_MUPEN64PLUS_NEXT
	test -d $(@D)/mupen64plus-libretro-nx/.git || \
		git clone --filter=blob:none $(MUPEN64PLUS_NEXT_SITE) $(@D)/mupen64plus-libretro-nx
	git -C $(@D)/mupen64plus-libretro-nx checkout $(MUPEN64PLUS_NEXT_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/mupen64plus-libretro-nx \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix \
		ARCH=aarch64 \
		FORCE_GLES=1
endef

################################################################################
# parallel_n64 - Nintendo 64 (대체 코어, GLideN64 렌더러)
################################################################################

PARALLEL_N64_SITE = https://github.com/libretro/parallel-n64
PARALLEL_N64_VERSION = 1a68b3bdebdd28936c7c74ac4365a097b44b1fe5

define LIBRETRO_CORES_BUILD_PARALLEL_N64
	test -d $(@D)/parallel-n64/.git || \
		git clone --filter=blob:none $(PARALLEL_N64_SITE) $(@D)/parallel-n64
	git -C $(@D)/parallel-n64 checkout $(PARALLEL_N64_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/parallel-n64 \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix \
		ARCH=aarch64 \
		FORCE_GLES=1
endef

################################################################################
# ppsspp - PlayStation Portable
# 서브모듈이 많은 대형 프로젝트(libretro 코어 빌드에 필요한 것만 초기화하면
# 이상적이지만, 어떤 서브모듈이 실제로 필요한지 사전 확인이 안 돼서
# 일단 전체(--recursive)로 받음 - 빌드 시간이 길 수 있음.
################################################################################

# 2026-07-12: platform 문자열에 "unix"가 있으면 if/else-if 체인에서 그 unix
# 분기가 먼저 매치되어 버려서 ARM64 전용 분기(정확한 aarch64 FFmpeg 경로,
# GLES 처리 포함)를 못 탐 - platform=arm64-gles로 "unix"를 빼고 "arm64"+
# "gles"만 넣어서 그 전용 분기를 직접 타게 함.
PPSSPP_SITE = https://github.com/hrydgard/ppsspp
PPSSPP_VERSION = f0baf3ade7bcb6c86f0835962b36eb4e51559d8f

define LIBRETRO_CORES_BUILD_PPSSPP
	test -d $(@D)/ppsspp/.git || \
		git clone --filter=blob:none $(PPSSPP_SITE) $(@D)/ppsspp
	git -C $(@D)/ppsspp checkout $(PPSSPP_VERSION)
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
		$(LIBRETRO_CROSS_OPTS) \
		platform=arm64-gles
endef

################################################################################
# kronos - Sega Saturn (GL 가속, beetle_saturn과 별개 코어)
# Batocera의 Odroid C4(S905X3) 레시피(platform=odroid-c4 FORCE_GLES=1) 그대로 사용.
# 저장소 자체가 "yabause" repo 안에 다시 "yabause" 하위 디렉토리를 갖는 구조.
################################################################################

KRONOS_SITE = https://github.com/libretro/yabause
KRONOS_VERSION = 146f4295eb7f5f76a2e6e6c84518c9bdf6a8398f

define LIBRETRO_CORES_BUILD_KRONOS
	test -d $(@D)/yabause/.git || \
		git clone --filter=blob:none --recurse-submodules $(KRONOS_SITE) $(@D)/yabause
	git -C $(@D)/yabause checkout $(KRONOS_VERSION)
	git -C $(@D)/yabause submodule update --init --recursive
	$(MAKE) -C $(@D)/yabause/yabause/src/libretro -f Makefile generate-files
	$(TARGET_CONFIGURE_OPTS) $(MAKE) $(LIBRETRO_CROSS_OPTS) -C $(@D)/yabause/yabause/src/libretro \
		-f Makefile \
		platform=odroid-c4 \
		FORCE_GLES=1
endef

################################################################################
# Build / Install
################################################################################

define LIBRETRO_CORES_BUILD_CMDS
	mkdir -p $(@D)
	$(call LIBRETRO_CORES_BUILD_FCEUMM)
	$(call LIBRETRO_CORES_BUILD_NESTOPIA)
	$(call LIBRETRO_CORES_BUILD_SNES9X)
	$(call LIBRETRO_CORES_BUILD_PCSX)
	$(call LIBRETRO_CORES_BUILD_BEETLE_PSX_HW)
	$(call LIBRETRO_CORES_BUILD_PICODRIVE)
	$(call LIBRETRO_CORES_BUILD_BLUEMSX)
	$(call LIBRETRO_CORES_BUILD_DOSBOX_PURE)
	$(call LIBRETRO_CORES_BUILD_SCUMMVM)
	$(call LIBRETRO_CORES_BUILD_QUASI88)
	$(call LIBRETRO_CORES_BUILD_NP2KAI)
	$(call LIBRETRO_CORES_BUILD_BEETLE_SATURN)
	$(call LIBRETRO_CORES_BUILD_MUPEN64PLUS_NEXT)
	$(call LIBRETRO_CORES_BUILD_PARALLEL_N64)
	$(call LIBRETRO_CORES_BUILD_PPSSPP)
	$(call LIBRETRO_CORES_BUILD_KRONOS)
endef

define LIBRETRO_CORES_INSTALL_TARGET_CMDS
	mkdir -p $(CORES_INSTALL_DIR)

	mkdir -p $(CORES_INSTALL_DIR)/lr-fceumm
	$(INSTALL) -m 0644 $(@D)/libretro-fceumm/fceumm_libretro.so \
		$(CORES_INSTALL_DIR)/lr-fceumm/
	echo "fceumm_libretro.so" > $(CORES_INSTALL_DIR)/lr-fceumm/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-nestopia
	$(INSTALL) -m 0644 $(@D)/nestopia/libretro/nestopia_libretro.so \
		$(CORES_INSTALL_DIR)/lr-nestopia/
	echo "nestopia_libretro.so" > $(CORES_INSTALL_DIR)/lr-nestopia/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-snes9x
	$(INSTALL) -m 0644 $(@D)/snes9x/libretro/snes9x_libretro.so \
		$(CORES_INSTALL_DIR)/lr-snes9x/
	echo "snes9x_libretro.so" > $(CORES_INSTALL_DIR)/lr-snes9x/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-pcsx-rearmed
	$(INSTALL) -m 0644 $(@D)/pcsx_rearmed/pcsx_rearmed_libretro.so \
		$(CORES_INSTALL_DIR)/lr-pcsx-rearmed/
	echo "pcsx_rearmed_libretro.so" > $(CORES_INSTALL_DIR)/lr-pcsx-rearmed/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-beetle-psx-hw
	$(INSTALL) -m 0644 $(@D)/beetle-psx-libretro/mednafen_psx_hw_libretro.so \
		$(CORES_INSTALL_DIR)/lr-beetle-psx-hw/
	echo "mednafen_psx_hw_libretro.so" > $(CORES_INSTALL_DIR)/lr-beetle-psx-hw/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-picodrive
	$(INSTALL) -m 0644 $(@D)/picodrive/picodrive_libretro.so \
		$(CORES_INSTALL_DIR)/lr-picodrive/
	echo "picodrive_libretro.so" > $(CORES_INSTALL_DIR)/lr-picodrive/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-bluemsx
	$(INSTALL) -m 0644 $(@D)/bluemsx-libretro/bluemsx_libretro.so \
		$(CORES_INSTALL_DIR)/lr-bluemsx/
	echo "bluemsx_libretro.so" > $(CORES_INSTALL_DIR)/lr-bluemsx/.installed_so_name
	mkdir -p $(TARGET_DIR)/usr/share/retropangui/bundled-bios
	cp -r $(@D)/bluemsx-libretro/system/bluemsx/Machines \
		$(TARGET_DIR)/usr/share/retropangui/bundled-bios/
	cp -r $(@D)/bluemsx-libretro/system/bluemsx/Databases \
		$(TARGET_DIR)/usr/share/retropangui/bundled-bios/

	mkdir -p $(CORES_INSTALL_DIR)/lr-dosbox-pure
	$(INSTALL) -m 0644 $(@D)/dosbox-pure/dosbox_pure_libretro.so \
		$(CORES_INSTALL_DIR)/lr-dosbox-pure/
	echo "dosbox_pure_libretro.so" > $(CORES_INSTALL_DIR)/lr-dosbox-pure/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-scummvm
	$(INSTALL) -m 0644 $(@D)/scummvm/backends/platform/libretro/scummvm_libretro.so \
		$(CORES_INSTALL_DIR)/lr-scummvm/
	echo "scummvm_libretro.so" > $(CORES_INSTALL_DIR)/lr-scummvm/.installed_so_name
	mkdir -p $(TARGET_DIR)/usr/share/retropangui/bundled-bios/scummvm
	$(INSTALL) -m 0644 $(@D)/scummvm/gui/themes/gui-icons.dat \
		$(TARGET_DIR)/usr/share/retropangui/bundled-bios/scummvm/
	$(INSTALL) -m 0644 $(@D)/scummvm/gui/themes/scummclassic.zip \
		$(TARGET_DIR)/usr/share/retropangui/bundled-bios/scummvm/
	$(INSTALL) -m 0644 $(@D)/scummvm/gui/themes/scummmodern.zip \
		$(TARGET_DIR)/usr/share/retropangui/bundled-bios/scummvm/

	mkdir -p $(CORES_INSTALL_DIR)/lr-quasi88
	$(INSTALL) -m 0644 $(@D)/quasi88-libretro/quasi88_libretro.so \
		$(CORES_INSTALL_DIR)/lr-quasi88/
	echo "quasi88_libretro.so" > $(CORES_INSTALL_DIR)/lr-quasi88/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-np2kai
	$(INSTALL) -m 0644 $(@D)/np2kai/sdl/np2kai_libretro.so \
		$(CORES_INSTALL_DIR)/lr-np2kai/
	echo "np2kai_libretro.so" > $(CORES_INSTALL_DIR)/lr-np2kai/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-beetle-saturn
	$(INSTALL) -m 0644 $(@D)/beetle-saturn-libretro/mednafen_saturn_libretro.so \
		$(CORES_INSTALL_DIR)/lr-beetle-saturn/
	echo "mednafen_saturn_libretro.so" > $(CORES_INSTALL_DIR)/lr-beetle-saturn/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-mupen64plus-next
	$(INSTALL) -m 0644 $(@D)/mupen64plus-libretro-nx/mupen64plus_next_libretro.so \
		$(CORES_INSTALL_DIR)/lr-mupen64plus-next/
	echo "mupen64plus_next_libretro.so" > $(CORES_INSTALL_DIR)/lr-mupen64plus-next/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-parallel-n64
	$(INSTALL) -m 0644 $(@D)/parallel-n64/parallel_n64_libretro.so \
		$(CORES_INSTALL_DIR)/lr-parallel-n64/
	echo "parallel_n64_libretro.so" > $(CORES_INSTALL_DIR)/lr-parallel-n64/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-ppsspp
	$(INSTALL) -m 0644 $(@D)/ppsspp/libretro/ppsspp_libretro.so \
		$(CORES_INSTALL_DIR)/lr-ppsspp/
	echo "ppsspp_libretro.so" > $(CORES_INSTALL_DIR)/lr-ppsspp/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-kronos
	$(INSTALL) -m 0644 $(@D)/yabause/yabause/src/libretro/kronos_libretro.so \
		$(CORES_INSTALL_DIR)/lr-kronos/
	echo "kronos_libretro.so" > $(CORES_INSTALL_DIR)/lr-kronos/.installed_so_name
endef

$(eval $(generic-package))
