#!/usr/bin/env bash
#
# 파일명: ext_retropie_core.sh
# RetroPangui Module: RetroPie 호환 환경 변수 정의
#
# RetroPie-Setup 스크립트와의 호환성을 위해 필요한 
# 1. 환경 설정 및 기본 유틸
# ===============================================

function setup_env() {
    __ERRMSGS=()
    __INFMSGS=()

    REQUIRED_PKGS=(git build-essential gcc g++ make dialog unzip lsb-release)
    for pkg in "${REQUIRED_PKGS[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            log_msg INFO "Installing prerequisite: $pkg ..."
            sudo apt-get install -y "$pkg"
        fi
    done

    export __memory_total_kb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
    export __memory_total=$(( __memory_total_kb / 1024 ))
    export __memory_avail_kb=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
    export __memory_avail=$(( __memory_avail_kb / 1024 ))
    export __jobs=$(nproc)
    export __default_makeflags="-j${__jobs}"

    export md_build="$INSTALL_BUILD_DIR/core_build"
    export md_inst="$LIBRETRO_CORE_PATH"
    mkdir -p "$md_build" "$md_inst"

    export __platform="$(uname -m)"
    export __os_id="$(lsb_release -si 2>/dev/null || echo "Unknown")"
    export __os_codename="$(lsb_release -sc 2>/dev/null || echo "Unknown")"

    export CFLAGS="-O2"
    export MAKEFLAGS="$__default_makeflags"
}

function mkUserDir() {
    mkdir -p "$1"
    chown "$__user":"$__group" "$1"
}

function mkRomDir() {
    local system="$1"
    local path="$USER_ROMS_PATH/$system"
    if [[ ! -d "$path" ]]; then
        log_msg INFO "Creating rom directory for '$system' at '$path'"
        mkdir -p "$path"
        chown "$__user":"$__user" "$path"
    fi
}

# escape special characters for sed
function sedQuote() {
    local string="$1"
    string="${string//\\/\\\\}"
    string="${string//|/\|}"
    string="${string//[/\[}"
    string="${string//]/\]}"
    echo "$string"
}