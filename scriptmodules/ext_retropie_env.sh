#!/usr/bin/env bash
#
# 파일명: env_ext_retropie.sh
# RetroPangui Module: RetroPie 호환 환경 변수 정의
#
# RetroPie-Setup 스크립트와의 호환성을 위해 필요한 환경 변수들을 여기에 정의합니다.
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
    
    # 추가: 스왑, BIOS, 설정 경로
    export __swapdir="$INSTALL_BUILD_DIR/swap"
    export biosdir="$USER_BIOS_PATH"
    export md_conf_root="$USER_CONFIG_PATH/cores"
    
    # 디렉토리 생성
    mkdir -p "$md_build" "$md_inst" "$__swapdir"
    mkUserDir "$biosdir"
    mkUserDir "$md_conf_root"

    export __os_id="$(lsb_release -si 2>/dev/null || echo "Unknown")"
    export __os_codename="$(lsb_release -sc 2>/dev/null || echo "Unknown")"

    export CFLAGS="-O2"
    export MAKEFLAGS="$__default_makeflags"
    
    log_msg DEBUG "환경 초기화 완료: 플랫폼=$__platform (${__platform_flags[*]}), GCC=$__gcc_version, 작업=$__jobs"
}


