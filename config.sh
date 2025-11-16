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
# config.sh가 프로젝트 루트에 위치하므로 .. 없이 현재 디렉토리가 ROOT_DIR입니다.
export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export MODULES_DIR="$ROOT_DIR/scriptmodules"
export RESOURCES_DIR="$ROOT_DIR/resources"

# --- [2] 공용 함수 로드 ---
# 사용자 정보를 가져오는 등의 함수를 사용하기 위해 먼저 로드합니다.
source "$MODULES_DIR/lib/func.sh"
source "$MODULES_DIR/lib/i18n.sh"

# --- [3] 사용자 및 홈 디렉토리 설정 ---
# sudo를 사용해도 실제 사용자 계정을 찾아서 적용합니다.
export __user="$(get_effective_user)"
export USER_HOME="$(eval echo ~$__user)"

# --- [4] 버전 및 핵심 경로 설정 ---
# 에뮬레이터 바이너리가 설치될 루트 디렉토리
export INSTALL_ROOT_DIR="/opt/retropangui"

# 임시 파일 경로
export TEMP_DIR_BASE="/tmp/retropangui"

# 빌드용 디렉토리
export INSTALL_BUILD_DIR="$TEMP_DIR_BASE"

# 로그 파일 경로 정의 (사용자 요청에 따라 수정)
export LOG_DIR="$ROOT_DIR/log"

# 레트로아크 코어 디렉토리 경로
export RETROARCH_BIN_PATH="$INSTALL_ROOT_DIR/bin/retroarch"
export LIBRETRO_CORE_PATH="$INSTALL_ROOT_DIR/libretrocores"

# RetroPie 호환성을 위한 추가 경로
export emudir="$INSTALL_ROOT_DIR/emulators"
export biosdir="$USER_BIOS_PATH"

# --- [5] 사용자별 경로 설정 (USER_HOME 기반) ---
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
export CORE_CONFIG_PATH="$USER_CONFIG_PATH/cores"
export RA_CONFIG_PATH="$USER_CONFIG_PATH/retroarch"

# RetroArch 및 EmulationStation 설정 파일 경로
export RA_CONFIG_DIR="$USER_HOME/.config/retroarch"
export ES_CONFIG_DIR="$USER_HOME/.emulationstation"

# --- [6] Git 및 기타 설정 ---
# 패치 및 설정 파일 참조용
export RETROPIE_SETUP_GIT_URL="https://github.com/RetroPie/RetroPie-Setup.git"

# 소스 코드 저장소
export RA_GIT_URL="https://github.com/libretro/RetroArch.git"
export RA_ASSETS_GIT_URL="https://github.com/libretro/retroarch-assets.git"
export RA_JOYPAD_AUTOCONFIG_GIT_URL="https://github.com/libretro/retroarch-joypad-autoconfig.git"
export RA_CORE_INFO_GIT_URL="https://github.com/libretro/libretro-core-info.git"
export RA_DATABASE_GIT_URL="https://github.com/libretro/libretro-database.git"
export RA_OVERLAYS_GIT_URL="https://github.com/libretro/common-overlays.git"
export RA_SHADERS_GIT_URL="https://github.com/libretro/glsl-shaders.git"
export ES_GIT_URL="https://github.com/LeonardWard/retropangui-emulationstation.git"

# Dialog 메뉴 설정 상수
export HEIGHT=20
export WIDTH=80
export CHOICE_HEIGHT=12

# --- [7] 빌드 의존성 패키지 목록 ---
export BUILD_DEPS=(
    build-essential cmake pkg-config
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

# --- [8] 플랫폼 탐지 ---
__platform_flags=()
__platform_arch=$(uname -m)
export __platform="$__platform_arch"

# CPU 플래그 초기화
__default_cpu_flags=""
__default_opt_flags="-O2"

# 기기별 상세 감지 함수
detect_device() {
    local arch=$(uname -m)

    # x86_64 아키텍처
    if [ "$arch" = "x86_64" ]; then
        echo "x86_64"
        return
    fi

    # ARM 계열: device-tree에서 모델명 파싱
    if [ -f /proc/device-tree/model ]; then
        local model=$(tr -d '\0' < /proc/device-tree/model)
        case "$model" in
            *"Raspberry Pi 3 Model B Plus"*) echo "rpi3b"; return;;
            *"Raspberry Pi 3 Model B"*) echo "rpi3b"; return;;
            *"Raspberry Pi 5"*) echo "rpi5"; return;;
            *"ODROID-C5"*) echo "odroidc5"; return;;
            *"ODROID-XU4"*) echo "odroidxu4"; return;;
        esac
    fi

    # 알 수 없는 기기
    echo "unknown"
}

# 감지된 기기 설정
__device=$(detect_device)
export __device

case "$__platform_arch" in
    x86_64)
        # x86_64 native 플랫폼 설정 (RetroPie 방식)
        __default_cpu_flags="-march=native"
        __platform_flags+=("$__platform_arch" "64bit" "x86" "gl" "vulkan" "x11")
        ;;
    aarch64)
        __platform_flags+=("aarch64" "64bit" "arm")

        # Odroid C5 전용 최적화
        if [ "$__device" = "odroidc5" ]; then
            __default_cpu_flags="-mcpu=cortex-a55 -mtune=cortex-a55"
            __platform_flags+=("odroidc5" "mali" "gles")
        # Raspberry Pi 5 최적화
        elif [ "$__device" = "rpi5" ]; then
            __default_cpu_flags="-mcpu=cortex-a76 -mtune=cortex-a76"
            __platform_flags+=("rpi5" "videocore" "gles")
        # Odroid N2 최적화
        elif [ "$__device" = "odroidn2" ]; then
            __default_cpu_flags="-mcpu=cortex-a73 -mtune=cortex-a73"
            __platform_flags+=("odroidn2" "mali" "gles")
        # Odroid C4 최적화
        elif [ "$__device" = "odroidc4" ]; then
            __default_cpu_flags="-mcpu=cortex-a55 -mtune=cortex-a55"
            __platform_flags+=("odroidc4" "mali" "gles")
        # 기타 aarch64 (일반)
        else
            __default_cpu_flags="-march=armv8-a"
            __platform_flags+=("gles")
        fi
        ;;
    armv7l)
        __platform_flags+=("armv7l" "32bit" "arm" "armv7")

        # Raspberry Pi 3B/3B+ 최적화
        if [ "$__device" = "rpi3b" ]; then
            __default_cpu_flags="-mcpu=cortex-a53 -mtune=cortex-a53"
            __platform_flags+=("rpi3b" "videocore" "gles")
        # Odroid XU4 최적화
        elif [ "$__device" = "odroidxu4" ]; then
            __default_cpu_flags="-mcpu=cortex-a15 -mtune=cortex-a15"
            __platform_flags+=("odroidxu4" "mali" "gles")
        # 기타 armv7l (일반)
        else
            __default_cpu_flags="-march=armv7-a -mfpu=neon-vfpv4"
            __platform_flags+=("gles")
        fi
        ;;
    *)
        __platform_flags+=("$__platform_arch")
        ;;
esac

# 플랫폼 관련 변수 export
export __platform_flags
export __default_cpu_flags
export __default_opt_flags

# GCC 버전 설정
__gcc_version=$(gcc -dumpversion | cut -d. -f1 2>/dev/null || echo "0")
export __gcc_version

# --- [9] 플랫폼별 설정 파일 로드 ---
export PLATFORMS_DIR="$ROOT_DIR/platforms"

# 공통 설정 로드
if [ -f "$PLATFORMS_DIR/common.conf" ]; then
    source "$PLATFORMS_DIR/common.conf"
fi

# 플랫폼별 설정 로드 (감지된 기기에 따라)
if [ -f "$PLATFORMS_DIR/${__device}.conf" ]; then
    source "$PLATFORMS_DIR/${__device}.conf"
    export PLATFORM_CONFIG_LOADED="yes"
    export PLATFORM_CONFIG_FILE="${__device}.conf"
else
    # 기기별 설정이 없으면 아키텍처 기반으로 로드
    if [ -f "$PLATFORMS_DIR/${__platform_arch}.conf" ]; then
        source "$PLATFORMS_DIR/${__platform_arch}.conf"
        export PLATFORM_CONFIG_LOADED="yes"
        export PLATFORM_CONFIG_FILE="${__platform_arch}.conf"
    else
        export PLATFORM_CONFIG_LOADED="no"
        export PLATFORM_CONFIG_FILE="none"
    fi
fi
