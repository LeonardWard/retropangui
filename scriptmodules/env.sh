#!/usr/bin/env bash

# =======================================================
# Retro Pangui Environment Setup
# 파일명: env.sh
# 설명: 모든 스크립트에서 공통으로 사용할 환경 변수를 설정하고 export합니다.
#       이 스크립트는 항상 프로젝트 루트에 위치한 메인 스크립트가 source해야 합니다.
# =======================================================

# --- [1] 기본 경로 설정 ---
# 이 스크립트를 source한 셸 스크립트의 위치를 기준으로 ROOT_DIR을 설정합니다.
# retropangui_setup.sh에서 source될 것이므로, ROOT_DIR은 프로젝트 루트가 됩니다.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULES_DIR="$ROOT_DIR/scriptmodules"

# --- [2] 공용 함수 로드 ---
# 사용자 정보를 가져오는 등의 함수를 사용하기 위해 먼저 로드합니다.
source "$MODULES_DIR/func.sh"

# --- [3] 사용자 및 홈 디렉토리 설정 ---
# sudo를 사용해도 실제 사용자 계정을 찾아서 적용합니다.
__user="$(get_effective_user)"
USER_HOME="$(eval echo ~$__user)"

# --- [4] 기본 설정 파일 로드 ---
# 경로와 사용자 변수가 설정된 후, 나머지 설정들을 불러옵니다.
# [수정] config.sh 파일을 source하기 전에, 윈도우 줄바꿈 문자를 제거하여 파일 자체를 정리합니다.
sed -i 's/\r$//' "$MODULES_DIR/config.sh"
source "$MODULES_DIR/config.sh"

# --- [5] 모든 변수 export ---
# 하위 스크립트나 프로세스에서 모든 변수를 사용할 수 있도록 export 합니다.
export ROOT_DIR
export MODULES_DIR
export __user
export USER_HOME

# config.sh에서 로드된 변수들
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
export ES_GIT_URL
export HEIGHT
export WIDTH
export CHOICE_HEIGHT
export BUILD_DEPS

