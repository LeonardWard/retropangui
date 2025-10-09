#!/usr/bin/env bash

# ===============================================
# Retro Pangui Global Configuration Variables
#
# 설명: 이 파일은 시스템 전체에서 사용되는 핵심 경로와 상수를 정의합니다.
#       env.sh에 의해 USER_HOME 같은 기본 변수가 설정된 후 source 됩니다.
# ===============================================

# --- [0] 버전 및 기본 경로 설정 ---
# Retro Pangui 스크립트 버전
__version="0.2"

# 에뮬레이터 바이너리가 설치될 루트 디렉토리
INSTALL_ROOT_DIR="/opt/retropangui"

# 임시 파일 경로
TEMP_DIR_BASE="/tmp/retropangui"

# 빌드용 디렉토리
INSTALL_BUILD_DIR="$TEMP_DIR_BASE"

# 로그 파일 경로 정의
LOG_DIR="$INSTALL_ROOT_DIR/logs"

# 레트로파이 코어 디렉토리 경로
LIBRETRO_CORE_PATH="$INSTALL_ROOT_DIR/libretro/cores"


# --- [1] 사용자별 경로 설정 (USER_HOME 기반) ---
# USER_HOME은 env.sh에서 미리 정의되어 넘어옵니다.

# Recalbox의 Share와 유사한 사용자 데이터 폴더
USER_SHARE_PATH="$USER_HOME/share"
USER_ROMS_PATH="$USER_SHARE_PATH/roms"
USER_BIOS_PATH="$USER_SHARE_PATH/bios"
USER_SAVES_PATH="$USER_SHARE_PATH/saves"
USER_SCREENS_PATH="$USER_SHARE_PATH/screenshots"
USER_MUSIC_PATH="$USER_SHARE_PATH/music"
USER_SPLASH_PATH="$USER_SHARE_PATH/splash_media"
USER_THEMES_PATH="$USER_SHARE_PATH/themes"
USER_OVERLAYS_PATH="$USER_SHARE_PATH/overlays"
USER_CHEATS_PATH="$USER_SHARE_PATH/cheats"

# 사용자 시스템 설정 및 로그 경로
USER_SYSTEM_PATH="$USER_SHARE_PATH/system"
USER_CONFIG_PATH="$USER_SYSTEM_PATH/configs"
USER_LOGS_PATH="$USER_SYSTEM_PATH/logs"
USER_SCRIPTS_PATH="$USER_SYSTEM_PATH/scripts"

# RetroArch 및 EmulationStation 설정 파일 경로
RA_CONFIG_DIR="$USER_HOME/.config/retroarch"
ES_CONFIG_DIR="$USER_HOME/.emulationstation"


# --- [2] Git 및 기타 설정 ---
# 패치 및 설정 파일 참조용
RECALBOX_GIT_URL="https://gitlab.com/recalbox/recalbox.git"
RETROPIE_SETUP_GIT_URL="https://github.com/RetroPie/RetroPie-Setup.git"

# 소스 코드 저장소
RA_GIT_URL="https://github.com/libretro/RetroArch.git"
ES_GIT_URL="https://github.com/RetroPie/EmulationStation.git"

# Whiptail 메뉴 설정 상수
HEIGHT=20
WIDTH=80
CHOICE_HEIGHT=12


# --- [3] 빌드 의존성 패키지 목록 ---
BUILD_DEPS=(
    build-essential cmake pkg-config samba
    # RetroArch/Libretro
    libssl-dev libx11-dev libgl1-mesa-dev libegl1-mesa-dev libsdl2-dev
    libasound-dev libudev-dev libxkbcommon-dev libgbm-dev
    libavcodec-dev libavformat-dev libavutil-dev libswscale-dev
    # EmulationStation
    libboost-all-dev libfreeimage-dev libcurl4-openssl-dev
    libxml2-dev libfontconfig1-dev libsdl2-image-dev libsdl2-ttf-dev libexpat1-dev
    libvlc-dev rapidjson-dev libpugixml-dev
)
