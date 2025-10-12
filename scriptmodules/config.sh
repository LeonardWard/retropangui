#!/usr/bin/env bash

# =======================================================
# Retro Pangui Global Configuration
# 파일명: config.sh
# 설명: 이 파일은 프로젝트의 모든 환경 변수, 경로, 설정을 정의하는
#       유일한 파일입니다. 모든 스크립트는 이 파일을 source하여
#       환경 설정을 로드해야 합니다.
# =======================================================

# --- [1] 기본 경로 설정 ---
# 이 파일의 위치를 기준으로 프로젝트의 루트 디렉토리를 정확하게 설정합니다.
# BASH_SOURCE[0]는 이 파일(config.sh)의 경로를 나타냅니다.
export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export MODULES_DIR="$ROOT_DIR/scriptmodules"

# --- [2] 공용 함수 로드 ---
# 사용자 정보를 가져오는 등의 함수를 사용하기 위해 먼저 로드합니다.
source "$MODULES_DIR/func.sh"

# --- [3] 사용자 및 홈 디렉토리 설정 ---
# sudo를 사용해도 실제 사용자 계정을 찾아서 적용합니다.
export __user="$(get_effective_user)"
export USER_HOME="$(eval echo ~$__user)"

# --- [4] 버전 및 핵심 경로 설정 ---
# Retro Pangui 스크립트 버전
export __version="0.3"

# 에뮬레이터 바이너리가 설치될 루트 디렉토리
export INSTALL_ROOT_DIR="/opt/retropangui"

# 임시 파일 경로
export TEMP_DIR_BASE="/tmp/retropangui"

# 빌드용 디렉토리
export INSTALL_BUILD_DIR="$TEMP_DIR_BASE"

# 로그 파일 경로 정의 (사용자 요청에 따라 수정)
export LOG_DIR="$ROOT_DIR/log"

# 레트로파이 코어 디렉토리 경로
export LIBRETRO_CORE_PATH="$INSTALL_ROOT_DIR/libretro/cores"

# --- [5] 사용자별 경로 설정 (USER_HOME 기반) ---
# Recalbox의 Share와 유사한 사용자 데이터 폴더
export USER_SHARE_PATH="$USER_HOME/share"
export USER_ROMS_PATH="$USER_SHARE_PATH/roms"
export USER_BIOS_PATH="$USER_SHARE_PATH/bios"
export USER_SAVES_PATH="$USER_SHARE_PATH/saves"
export USER_SCREENS_PATH="$USER_SHARE_PATH/screenshots"
export USER_MUSIC_PATH="$USER_SHARE_PATH/music"
export USER_SPLASH_PATH="$USER_SHARE_PATH/splash_media"
export USER_THEMES_PATH="$USER_SHARE_PATH/themes"
export USER_OVERLAYS_PATH="$USER_SHARE_PATH/overlays"
export USER_CHEATS_PATH="$USER_SHARE_PATH/cheats"

# 사용자 시스템 설정 및 로그 경로
export USER_SYSTEM_PATH="$USER_SHARE_PATH/system"
export USER_CONFIG_PATH="$USER_SYSTEM_PATH/configs"
export USER_LOGS_PATH="$USER_SYSTEM_PATH/logs"
export USER_SCRIPTS_PATH="$USER_SYSTEM_PATH/scripts"

# RetroArch 및 EmulationStation 설정 파일 경로
export RA_CONFIG_DIR="$USER_HOME/.config/retroarch"
export ES_CONFIG_DIR="$USER_HOME/.emulationstation"

# --- [6] Git 및 기타 설정 ---
# 패치 및 설정 파일 참조용
export RECALBOX_GIT_URL="https://gitlab.com/recalbox/recalbox.git"
export RETROPIE_SETUP_GIT_URL="https://github.com/RetroPie/RetroPie-Setup.git"

# 소스 코드 저장소
export RA_GIT_URL="https://github.com/libretro/RetroArch.git"
export RA_ASSETS_GIT_URL="https://github.com/libretro/retroarch-assets.git"
export ES_GIT_URL="https://github.com/RetroPie/EmulationStation.git"

# Whiptail 메뉴 설정 상수
export HEIGHT=20
export WIDTH=80
export CHOICE_HEIGHT=12

# --- [7] 빌드 의존성 패키지 목록 ---
export BUILD_DEPS=(
    build-essential cmake pkg-config samba
    # RetroArch/Libretro
    libssl-dev libx11-dev libgl1-mesa-dev libegl1-mesa-dev libsdl2-dev
    libasound2-dev libudev-dev libxkbcommon-dev libgbm-dev
    libavcodec-dev libavformat-dev libavutil-dev libswscale-dev
    # EmulationStation
    libboost-all-dev libfreeimage-dev libcurl4-openssl-dev
    libxml2-dev libfontconfig1-dev libsdl2-image-dev libsdl2-ttf-dev libexpat1-dev
    libvlc-dev rapidjson-dev libpugixml-dev
    # 그 외 게임에 필요한 패키지
    gamemode
)