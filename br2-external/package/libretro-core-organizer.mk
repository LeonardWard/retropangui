################################################################################
#
# libretro-core-organizer.mk
#
# 24개 libretro 코어 패키지의 _VERSION(git 커밋 해시/태그)과 _SITE(저장소 URL)를
# 한곳에 모아두는 중앙 관리 파일 - 각 libretro-core-<name>.mk는 이 파일을
# include해서 값을 받아쓰고, _SOURCE/_DEPENDENCIES/CROSS_OPTS/BUILD_CMDS/
# INSTALL_CMDS처럼 그 코어 고유 로직만 자기 파일에 남긴다.
#
# 목적(2026-07-19 사용자 지시, todo-20260712-libretro-cores-package-split.html
# 후속 작업 1): 코어가 24개로 늘면서 버전/사이트 값이 파일마다 흩어져 있어
# 한눈에 보거나 일괄 관리하기 어려웠음 - 이 파일이 그 정리 창구(organizer) 역할.
#
# 2026-07-14 코어별 패키지 분해(총괄 .mk 폐기 -> 완전 독립)의 목적과 충돌하지
# 않음 - Buildroot 캐시 미감지 문제는 각 코어의 빌드 커맨드가 한 패키지 안에
# 묶여 있던 게 원인이었지, 단순 변수 값을 어디서 include하든 각 패키지의
# output/build/<pkg>-* 캐시 독립성과는 무관함.
#
# 주의: 이 파일 변경 시 scripts/detect-stale-package-caches.sh가 바뀐
# <PREFIX>_VERSION 라인을 diff로 감지해서 해당 코어 패키지 캐시만 정리함
# (todo-20260720-build-force-clean-audit.html 참고) - 코어 하나 버전만 올려도
# 전체가 아니라 그 코어만 재빌드됨.
#
################################################################################

# beetle-bsnes
LIBRETRO_CORE_BEETLE_BSNES_VERSION = e2b7694d12c44a2842cf4640844287f622026d9a
LIBRETRO_CORE_BEETLE_BSNES_SITE = https://github.com/libretro/beetle-bsnes-libretro

# beetle-pce
LIBRETRO_CORE_BEETLE_PCE_VERSION = ae99235c2139c176c1a8d0fde2957bf701d3cab0
LIBRETRO_CORE_BEETLE_PCE_SITE = https://github.com/libretro/beetle-pce-libretro

# beetle-psx-hw
LIBRETRO_CORE_BEETLE_PSX_HW_VERSION = d460f8342060526678e7fd8222048324c2a80d86
LIBRETRO_CORE_BEETLE_PSX_HW_SITE = https://github.com/libretro/beetle-psx-libretro

# beetle-saturn
LIBRETRO_CORE_BEETLE_SATURN_VERSION = 6f0cb9d1b9689601cd7dbf08e992d232304f50f7
LIBRETRO_CORE_BEETLE_SATURN_SITE = https://github.com/libretro/beetle-saturn-libretro

# beetle-supergrafx
LIBRETRO_CORE_BEETLE_SUPERGRAFX_VERSION = 3c6fcd3deded54ebecd69408f108407ac03d11b5
LIBRETRO_CORE_BEETLE_SUPERGRAFX_SITE = https://github.com/libretro/beetle-supergrafx-libretro

# bluemsx
LIBRETRO_CORE_BLUEMSX_VERSION = b76f27959a32e18aa04c619273152178fd0cf03b
LIBRETRO_CORE_BLUEMSX_SITE = https://github.com/libretro/bluemsx-libretro

# dosbox-pure
LIBRETRO_CORE_DOSBOX_PURE_VERSION = f587236b2d016f4f16d672e9ce2829bdf507bf9b
LIBRETRO_CORE_DOSBOX_PURE_SITE = https://github.com/schellingb/dosbox-pure

# fbneo
LIBRETRO_CORE_FBNEO_VERSION = 808243ba2a95061e6bd2a86829dc54b46dfded99
LIBRETRO_CORE_FBNEO_SITE = https://github.com/libretro/FBNeo

# fceumm
LIBRETRO_CORE_FCEUMM_VERSION = c0c52ad0eb36cdbfc66e9bdb72efc83103e85e22
LIBRETRO_CORE_FCEUMM_SITE = https://github.com/libretro/libretro-fceumm

# kronos
LIBRETRO_CORE_KRONOS_VERSION = 146f4295eb7f5f76a2e6e6c84518c9bdf6a8398f
LIBRETRO_CORE_KRONOS_SITE = https://github.com/libretro/yabause

# mame2003-plus
LIBRETRO_CORE_MAME2003_PLUS_VERSION = 2cca4441706b952c2eaf8264713b53fd5452e0bd
LIBRETRO_CORE_MAME2003_PLUS_SITE = https://github.com/libretro/mame2003-plus-libretro

# mame2010
LIBRETRO_CORE_MAME2010_VERSION = 484456818393505dd4367e6e4c116c573c04a1ec
LIBRETRO_CORE_MAME2010_SITE = https://github.com/libretro/mame2010-libretro

# mame2016
LIBRETRO_CORE_MAME2016_VERSION = 3529f4e2cb8e74c88d83bc9fc9d695f78dc9a975
LIBRETRO_CORE_MAME2016_SITE = https://github.com/libretro/mame2016-libretro

# mupen64plus-next
LIBRETRO_CORE_MUPEN64PLUS_NEXT_VERSION = 98c1b0d877542b01314b3b04272282ba223b65b3
LIBRETRO_CORE_MUPEN64PLUS_NEXT_SITE = https://github.com/libretro/mupen64plus-libretro-nx

# nestopia
LIBRETRO_CORE_NESTOPIA_VERSION = b0fd87dd07e3c52903435d302b04e5e97796f127
LIBRETRO_CORE_NESTOPIA_SITE = https://github.com/libretro/nestopia

# np2kai
LIBRETRO_CORE_NP2KAI_VERSION = 54ec39f50d197cc02909cd4fd2a8591bb38651b0
LIBRETRO_CORE_NP2KAI_SITE = https://github.com/libretro/np2kai

# parallel-n64
LIBRETRO_CORE_PARALLEL_N64_VERSION = 1a68b3bdebdd28936c7c74ac4365a097b44b1fe5
LIBRETRO_CORE_PARALLEL_N64_SITE = https://github.com/libretro/parallel-n64

# pcsx-rearmed
LIBRETRO_CORE_PCSX_REARMED_VERSION = r26l
LIBRETRO_CORE_PCSX_REARMED_SITE = https://github.com/libretro/pcsx_rearmed

# picodrive
LIBRETRO_CORE_PICODRIVE_VERSION = f0d4a0118a9733a1f10bce5a4ac772c474f9300d
LIBRETRO_CORE_PICODRIVE_SITE = https://github.com/libretro/picodrive

# ppsspp
LIBRETRO_CORE_PPSSPP_VERSION = f0baf3ade7bcb6c86f0835962b36eb4e51559d8f
LIBRETRO_CORE_PPSSPP_SITE = https://github.com/hrydgard/ppsspp

# quasi88
LIBRETRO_CORE_QUASI88_VERSION = 520e0a37ac0e9cf8b0536fe83fda3aacc9ba73bb
LIBRETRO_CORE_QUASI88_SITE = https://github.com/libretro/quasi88-libretro

# scummvm
LIBRETRO_CORE_SCUMMVM_VERSION = libretro-v3.1.0.1
LIBRETRO_CORE_SCUMMVM_SITE = https://github.com/libretro/scummvm

# snes9x
LIBRETRO_CORE_SNES9X_VERSION = e755ae51b61f49e4ac48bdeaa16e3c72e70db0e5
LIBRETRO_CORE_SNES9X_SITE = https://github.com/libretro/snes9x

# yabasanshiro
LIBRETRO_CORE_YABASANSHIRO_VERSION = f448097b69a6037246a08e9dc09eabaa420d7893
LIBRETRO_CORE_YABASANSHIRO_SITE = https://github.com/libretro/yabause
