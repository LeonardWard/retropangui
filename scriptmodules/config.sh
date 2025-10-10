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
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULES_DIR="$ROOT_DIR/scriptmodules"

# --- [2] 공용 함수 로드 ---
# 사용자 정보를 가져오는 등의 함수를 사용하기 위해 먼저 로드합니다.
source "$MODULES_DIR/func.sh"

# --- [3] 사용자 및 홈 디렉토리 설정 ---
# sudo를 사용해도 실제 사용자 계정을 찾아서 적용합니다.
__user="$(get_effective_user)"
USER_HOME="$(eval echo ~$__user)"

# --- [4] 버전 및 핵심 경로 설정 ---
# Retro Pangui 스크립트 버전
__version="0.3"

# 에뮬레이터 바이너리가 설치될 루트 디렉토리
INSTALL_ROOT_DIR="/opt/retropangui"

# 임시 파일 경로
TEMP_DIR_BASE="/tmp/retropangui"

# 빌드용 디렉토리
INSTALL_BUILD_DIR="$TEMP_DIR_BASE"

# 로그 파일 경로 정의 (사용자 요청에 따라 수정)
LOG_DIR="$ROOT_DIR/log"

# 레트로파이 코어 디렉토리 경로
LIBRETRO_CORE_PATH="$INSTALL_ROOT_DIR/libretro/cores"

# --- [5] 사용자별 경로 설정 (USER_HOME 기반) ---
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

# --- [6] Git 및 기타 설정 ---
# 패치 및 설정 파일 참조용
RECALBOX_GIT_URL="https://gitlab.com/recalbox/recalbox.git"
RETROPIE_SETUP_GIT_URL="https://github.com/RetroPie/RetroPie-Setup.git"

# 소스 코드 저장소
RA_GIT_URL="https://github.com/libretro/RetroArch.git"
RA_ASSETS_GIT_URL="https://github.com/libretro/retroarch-assets.git"
ES_GIT_URL="https://github.com/RetroPie/EmulationStation.git"

# Whiptail 메뉴 설정 상수
HEIGHT=20
WIDTH=80
CHOICE_HEIGHT=12

# --- [7] 빌드 의존성 패키지 목록 ---
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

# --- [8] 모든 변수 export ---
# 하위 스크립트나 프로세스에서 모든 변수를 사용할 수 있도록 export 합니다.
export ROOT_DIR
export MODULES_DIR
export __user
export USER_HOME
export __version
export INSTALL_ROOT_DIR
export TEMP_DIR_BASE
export INSTALL_BUILD_DIR
export LOG_DIR
export LIBRETRO_CORE_PATH
export USER_SHARE_PATH
export USER_ROMS_PATH
export USER_BIOS_PATH
export USER_SAVES_PATH
export USER_SCREENS_PATH
export USER_MUSIC_PATH
export USER_SPLASH_PATH
export USER_THEMES_PATH
export USER_OVERLAYS_PATH
export USER_CHEATS_PATH
export USER_SYSTEM_PATH
export USER_CONFIG_PATH
export USER_LOGS_PATH
export USER_SCRIPTS_PATH
export RA_CONFIG_DIR
export ES_CONFIG_DIR
export RECALBOX_GIT_URL
export RETROPIE_SETUP_GIT_URL
export RA_GIT_URL
export RA_ASSETS_GIT_URL
export ES_GIT_URL
export HEIGHT
export WIDTH
export CHOICE_HEIGHT
export BUILD_DEPS