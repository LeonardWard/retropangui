################################################################################
#
# libretro-core-organizer.mk
#
# 24개 libretro 코어 패키지의 _VERSION(git 커밋 해시/태그)·_SITE(저장소 URL)·
# _PLATFORM(코어 빌드 커맨드에 넘기는 platform= 값)을 한곳에 모아두는 중앙
# 관리 파일. 각 libretro-core-<name>.mk는 이 값을 받아쓰고
# _SOURCE/_DEPENDENCIES/CROSS_OPTS/BUILD_CMDS/INSTALL_CMDS처럼 그 코어 고유
# 로직만 자기 파일에 남긴다.
#
# 목적(2026-07-19 사용자 지시, todo-20260712-libretro-cores-package-split.html
# 후속 작업 1·2): 코어가 24개로 늘면서 값이 파일마다 흩어져 있어 한눈에 보거나
# 일괄 관리하기 어려웠음 - 이 파일이 그 정리 창구(organizer) 역할. 특히
# _PLATFORM은 지금은 기기가 odroidc5 하나뿐이라 코어당 값 1개지만, 이
# 파일이 "코어 × 기기 → 값" 매트릭스의 자리를 미리 잡아둔 것 - 두 번째
# 기기가 생기면 mame2016처럼 ifeq($(BR2_x86_64),y)/... 분기로 값만 늘리면
# 되고, 24개 코어의 BUILD_CMDS(platform=$(<PREFIX>_PLATFORM) 참조)는 전혀
# 손댈 필요 없음(2026-07-21, 사용자 방향 확정 - "가능한 값의 특정 + 기기
# 정보에 의한 선택 + 플랫폼 값 전달"이 이 파일의 역할).
#
# ⚠ include는 br2-external/external.mk에서 1회만 - 개별 패키지 .mk 안에서
# include하면 Buildroot의 패키지명 추론(pkg-utils.mk의
# $(dir $(lastword $(MAKEFILE_LIST))))이 깨져서 모든 코어가 "package"라는
# 같은 이름으로 등록되려다 충돌함(2026-07-21 실빌드로 실측, external.mk 참고).
#
# 2026-07-14 코어별 패키지 분해(총괄 .mk 폐기 -> 완전 독립)의 목적과 충돌하지
# 않음 - Buildroot 캐시 미감지 문제는 각 코어의 빌드 커맨드가 한 패키지 안에
# 묶여 있던 게 원인이었지, 단순 변수 값을 어디서 include하든 각 패키지의
# output/build/<pkg>-* 캐시 독립성과는 무관함.
#
# 주의: 이 파일 변경 시 scripts/detect-stale-package-caches.sh가 바뀐
# <PREFIX>_VERSION/_SITE/_PLATFORM 라인을 diff로 감지해서 해당 코어 패키지
# 캐시만 정리함(todo-20260720-build-force-clean-audit.html 참고) - 코어
# 하나 값만 바뀌어도 전체가 아니라 그 코어만 재빌드됨.
#
# ── 코어 추가 시 아키텍처 관련 흔한 함정(후속 작업 2, 2026-07-19 전수 조사) ──
# 코어마다 업스트림 Makefile 구조가 달라 완전 통일은 불가능(코어 소스는
# 패치하지 않는 방침) - 아래는 지금까지 실측된 패턴, 새 코어 추가 시 이
# 표부터 대조해서 같은 시행착오 반복을 줄인다:
#   · platform=unix (기본값, 대다수 코어) - 별도 처리 불필요
#   · platform=odroid-c4 (kronos, yabasanshiro) - platform=unix가 x86_64
#     SSE 플래그(-mfpmath=sse)를 강제해 크로스빌드가 깨지는 코어의 우회.
#     Batocera Odroid C4 레시피 재사용, HAVE_SSE=0 + FORCE_GLES=1 자동 설정.
#     ⚠ 이 두 코어를 애초에 시도한 배경은 "C5가 Vulkan을 지원한다"는 잘못된
#     정보였음(2026-07-21 확인) - platform=odroid-c4 우회 자체는 여전히
#     유효하지만, 코어 선택 판단 근거는 아니었다는 걸 기록해둠.
#   · platform=arm64-gles (ppsspp) - "unix"가 들어간 값은 if/else-if 체인에서
#     unix 분기가 먼저 매치돼 ARM64 전용 분기(정확한 aarch64 FFmpeg 경로,
#     GLES 처리)를 못 탐 - "unix"를 아예 빼고 arm64+gles 조합으로 전용
#     분기를 직접 타게 함. 실사용 결과 잘 작동(정상 케이스, 위험 신호 아님).
#   · HAVE_NEON=0 (fbneo) - "aarch64니까 NEON 당연히 있다"는 직관과 반대로,
#     이 코어 Makefile은 HAVE_NEON=1일 때 ARM32 전용 GCC 플래그
#     (-mvectorize-with-neon-quad)를 강제해서 오히려 실패함.
#   · PTR64=1 ARM_ENABLED=0 FORCE_DRC_C_BACKEND=1 + CXX 명시 (mame2010) -
#     makefile이 최종 링크에 $(CXX)를 쓰는데 기본값이 없어 host g++로 링크되던
#     문제가 진짜 원인이었음(ARM_ENABLED/AR 가설은 전부 배제됨, 4라운드 시행착오).
#   · genie/premake host 전용 빌드 도구 + PTR64/ARCHITECTURE (mame2016) -
#     6라운드 끝에 x86_64 전용 빌드시스템으로 확인, aarch64 비활성화.
# 상세 경위는 각 todo-core-lr-<name>.html 참고.
#
################################################################################

# beetle-bsnes
LIBRETRO_CORE_BEETLE_BSNES_VERSION = e2b7694d12c44a2842cf4640844287f622026d9a
LIBRETRO_CORE_BEETLE_BSNES_SITE = https://github.com/libretro/beetle-bsnes-libretro
LIBRETRO_CORE_BEETLE_BSNES_PLATFORM = unix

# beetle-pce
LIBRETRO_CORE_BEETLE_PCE_VERSION = ae99235c2139c176c1a8d0fde2957bf701d3cab0
LIBRETRO_CORE_BEETLE_PCE_SITE = https://github.com/libretro/beetle-pce-libretro
LIBRETRO_CORE_BEETLE_PCE_PLATFORM = unix

# beetle-psx-hw
LIBRETRO_CORE_BEETLE_PSX_HW_VERSION = d460f8342060526678e7fd8222048324c2a80d86
LIBRETRO_CORE_BEETLE_PSX_HW_SITE = https://github.com/libretro/beetle-psx-libretro
LIBRETRO_CORE_BEETLE_PSX_HW_PLATFORM = unix

# beetle-saturn
LIBRETRO_CORE_BEETLE_SATURN_VERSION = 6f0cb9d1b9689601cd7dbf08e992d232304f50f7
LIBRETRO_CORE_BEETLE_SATURN_SITE = https://github.com/libretro/beetle-saturn-libretro
LIBRETRO_CORE_BEETLE_SATURN_PLATFORM = unix

# beetle-supergrafx
LIBRETRO_CORE_BEETLE_SUPERGRAFX_VERSION = 3c6fcd3deded54ebecd69408f108407ac03d11b5
LIBRETRO_CORE_BEETLE_SUPERGRAFX_SITE = https://github.com/libretro/beetle-supergrafx-libretro
LIBRETRO_CORE_BEETLE_SUPERGRAFX_PLATFORM = unix

# bluemsx
LIBRETRO_CORE_BLUEMSX_VERSION = b76f27959a32e18aa04c619273152178fd0cf03b
LIBRETRO_CORE_BLUEMSX_SITE = https://github.com/libretro/bluemsx-libretro
LIBRETRO_CORE_BLUEMSX_PLATFORM = unix

# dosbox-pure
LIBRETRO_CORE_DOSBOX_PURE_VERSION = f587236b2d016f4f16d672e9ce2829bdf507bf9b
LIBRETRO_CORE_DOSBOX_PURE_SITE = https://github.com/schellingb/dosbox-pure
LIBRETRO_CORE_DOSBOX_PURE_PLATFORM = unix

# fbneo
LIBRETRO_CORE_FBNEO_VERSION = 808243ba2a95061e6bd2a86829dc54b46dfded99
LIBRETRO_CORE_FBNEO_SITE = https://github.com/libretro/FBNeo
LIBRETRO_CORE_FBNEO_PLATFORM = unix

# fceumm
LIBRETRO_CORE_FCEUMM_VERSION = c0c52ad0eb36cdbfc66e9bdb72efc83103e85e22
LIBRETRO_CORE_FCEUMM_SITE = https://github.com/libretro/libretro-fceumm
LIBRETRO_CORE_FCEUMM_PLATFORM = unix

# kronos
LIBRETRO_CORE_KRONOS_VERSION = 146f4295eb7f5f76a2e6e6c84518c9bdf6a8398f
LIBRETRO_CORE_KRONOS_SITE = https://github.com/libretro/yabause
LIBRETRO_CORE_KRONOS_PLATFORM = odroid-c4

# mame2003-plus
LIBRETRO_CORE_MAME2003_PLUS_VERSION = 2cca4441706b952c2eaf8264713b53fd5452e0bd
LIBRETRO_CORE_MAME2003_PLUS_SITE = https://github.com/libretro/mame2003-plus-libretro
LIBRETRO_CORE_MAME2003_PLUS_PLATFORM = unix

# mame2010
LIBRETRO_CORE_MAME2010_VERSION = 484456818393505dd4367e6e4c116c573c04a1ec
LIBRETRO_CORE_MAME2010_SITE = https://github.com/libretro/mame2010-libretro
LIBRETRO_CORE_MAME2010_PLATFORM = unix

# mame2016
LIBRETRO_CORE_MAME2016_VERSION = 3529f4e2cb8e74c88d83bc9fc9d695f78dc9a975
LIBRETRO_CORE_MAME2016_SITE = https://github.com/libretro/mame2016-libretro
# platform 값 자체는 aarch64/x86_64 타겟 무관하게 동일("unix") - 이 코어의
# 실제 기기별 차이는 genie 사전빌드/NOASM/ARCHITECTURE 등 다른 플래그에 있고
# 이번 정리 범위 밖(코어 파일에 그대로 남아있음). aarch64(odroidc5)에서는
# defconfig에서 코어 자체가 꺼져 있어 이 값이 안 쓰임.
LIBRETRO_CORE_MAME2016_PLATFORM = unix

# mupen64plus-next
LIBRETRO_CORE_MUPEN64PLUS_NEXT_VERSION = 98c1b0d877542b01314b3b04272282ba223b65b3
LIBRETRO_CORE_MUPEN64PLUS_NEXT_SITE = https://github.com/libretro/mupen64plus-libretro-nx
LIBRETRO_CORE_MUPEN64PLUS_NEXT_PLATFORM = unix

# nestopia
LIBRETRO_CORE_NESTOPIA_VERSION = b0fd87dd07e3c52903435d302b04e5e97796f127
LIBRETRO_CORE_NESTOPIA_SITE = https://github.com/libretro/nestopia
LIBRETRO_CORE_NESTOPIA_PLATFORM = unix

# np2kai
LIBRETRO_CORE_NP2KAI_VERSION = 54ec39f50d197cc02909cd4fd2a8591bb38651b0
LIBRETRO_CORE_NP2KAI_SITE = https://github.com/libretro/np2kai
LIBRETRO_CORE_NP2KAI_PLATFORM = unix

# parallel-n64
LIBRETRO_CORE_PARALLEL_N64_VERSION = 1a68b3bdebdd28936c7c74ac4365a097b44b1fe5
LIBRETRO_CORE_PARALLEL_N64_SITE = https://github.com/libretro/parallel-n64
LIBRETRO_CORE_PARALLEL_N64_PLATFORM = unix

# pcsx-rearmed
LIBRETRO_CORE_PCSX_REARMED_VERSION = r26l
LIBRETRO_CORE_PCSX_REARMED_SITE = https://github.com/libretro/pcsx_rearmed
LIBRETRO_CORE_PCSX_REARMED_PLATFORM = unix

# picodrive
LIBRETRO_CORE_PICODRIVE_VERSION = f0d4a0118a9733a1f10bce5a4ac772c474f9300d
LIBRETRO_CORE_PICODRIVE_SITE = https://github.com/libretro/picodrive
LIBRETRO_CORE_PICODRIVE_PLATFORM = unix

# ppsspp
LIBRETRO_CORE_PPSSPP_VERSION = f0baf3ade7bcb6c86f0835962b36eb4e51559d8f
LIBRETRO_CORE_PPSSPP_SITE = https://github.com/hrydgard/ppsspp
LIBRETRO_CORE_PPSSPP_PLATFORM = arm64-gles

# quasi88
LIBRETRO_CORE_QUASI88_VERSION = 520e0a37ac0e9cf8b0536fe83fda3aacc9ba73bb
LIBRETRO_CORE_QUASI88_SITE = https://github.com/libretro/quasi88-libretro
LIBRETRO_CORE_QUASI88_PLATFORM = unix

# scummvm
LIBRETRO_CORE_SCUMMVM_VERSION = libretro-v3.1.0.1
LIBRETRO_CORE_SCUMMVM_SITE = https://github.com/libretro/scummvm
LIBRETRO_CORE_SCUMMVM_PLATFORM = unix

# snes9x
LIBRETRO_CORE_SNES9X_VERSION = e755ae51b61f49e4ac48bdeaa16e3c72e70db0e5
LIBRETRO_CORE_SNES9X_SITE = https://github.com/libretro/snes9x
LIBRETRO_CORE_SNES9X_PLATFORM = unix

# yabasanshiro
LIBRETRO_CORE_YABASANSHIRO_VERSION = f448097b69a6037246a08e9dc09eabaa420d7893
LIBRETRO_CORE_YABASANSHIRO_SITE = https://github.com/libretro/yabause
LIBRETRO_CORE_YABASANSHIRO_PLATFORM = odroid-c4
