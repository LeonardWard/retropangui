#!/usr/bin/env bash
# 파일명: func_ext_retropie.sh
# RetroPangui 커스텀 헬퍼 함수 모음
# RetroPie의 헬퍼 함수를 사용하는 대신, Retro Pang-ui에 맞게 직접 구현합니다.

# 1. 고유 헬퍼 함수들 (재정의된 RetroPie 호환 함수 포함)

function mkRomDir() {
    local system="$1"
    local path="$USER_ROMS_PATH/$system"
    if [[ ! -d "$path" ]]; then
        log_msg INFO "Creating rom directory for '$system' at '$path'"
        mkdir -p "$path"
        chown "$__user":"$__user" "$path"
    fi
}

function addEmulator() {
    local is_default="$1"
    local emu="$2"
    local system="$3"
    local command="$4"
    local config_file="$USER_HOME/share/system/configs/$system/emulators.cfg"

    log_msg INFO "Adding emulator '$emu' for system '$system' to '$config_file'"
    mkdir -p "$(dirname "$config_file")"
    
    echo "$emu = \"$command\"" >> "$config_file"

    if [[ "$is_default" -eq 1 ]]; then
        # 기존 default 라인을 지우고 새로 추가
        sed -i '/^default = /d' "$config_file"
        echo "default = \"$emu\"" >> "$config_file"
    fi
    chown "$__user":"$__user" "$config_file"
}

function addSystem() {
    return 0
}

function defaultRAConfig() {

    local system="
"

    local dest_config="$USER_CONFIG_PATH/$system/retroarch.cfg"

    local src_config="/opt/retropangui/etc/retroarch.cfg"



    if [[ -f "$src_config" ]]; then

        log_msg INFO "Copying default retroarch.cfg to '$dest_config'"

        mkdir -p "$(dirname "$dest_config")"

        if [[ ! -f "$dest_config" ]]; then

            cp "$src_config" "$dest_config"

            chown "$__user":"$__user" "$dest_config"

        fi

    else

        log_msg WARN "Default retroarch.cfg not found at '$src_config'"

    fi

}



function rp_isInstalled() {

    return 1 # 1 indicates 'not installed'

}



function iniConfig() {

    _ini_file="
"

    mkdir -p "$(dirname "$_ini_file")"

    if [[ ! -f "$_ini_file" ]]; then

        touch "$_ini_file"

        chown "$__user":"$__user" "$_ini_file"

    fi

}



function iniGet() {

    local key="
"

    local file="${2:-$_ini_file}"

    local value=$(grep -E "^${key}(\s+)?=" "$file" | head -n 1 | cut -d'=' -f2 | sed 's/"//g' | sed 's/^[ ]*//;s/[ ]*$//')

    echo "$value"

}



function iniSet() {

    local key="
"

    local value="$2"

    local file="${3:-$_ini_file}"

    if [[ -n "$file" && -f "$file" ]]; then

        # sed 명령어에서 특수문자(특히 /) 문제를 피하기 위해 value를 이스케이프 처리합니다.

        local escaped_value=$(printf '%s' "$value" | sed 's/[\/&]/\\&/g')

        if grep -q -E "^${key}(\s+)?=" "$file"; then

            sed -i "s/^\(${key}\s*=\s*\).* /\1\"${escaped_value}\"" "$file"

        else

            echo "$key = \"$escaped_value\"" >> "$file"

        fi

        chown "$__user":"$__user" "$file"

    fi

}

# 2. 고유 헬퍼 함수들 (기존 코드 복원)

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

    export md_build="/tmp/build"
    export md_inst="/opt/retropangui/libretro/cores"
    mkdir -p "$md_build" "$md_inst"

    export __platform="$(uname -m)"
    export __os_id="$(lsb_release -si 2>/dev/null || echo "Unknown")"
    export __os_codename="$(lsb_release -sc 2>/dev/null || echo "Unknown")"

    export CFLAGS="-O2"
    export MAKEFLAGS="$__default_makeflags"
}

function gitPullOrClone() {
    log_msg INFO "gitPullOrClone wrapper executed..."

    local repo_info="$rp_module_repo"
    local dest_dir="${md_build}/${rp_module_id}"

    local type url branch
    read -r type url branch <<< "$repo_info"

    if [[ "$type" != "git" ]] || [[ -z "$url" ]]; then
        log_msg ERROR "Invalid repository URL: $repo_info"
        return 1
    fi
    
    if [[ -n "$branch" ]]; then
        git_Pull_Or_Clone "$url" "$dest_dir" --branch "$branch" --depth=1
    else
        git_Pull_Or_Clone "$url" "$dest_dir" --depth=1
    fi
}

function installLibretroCore() {
    log_msg INFO "Installing compiled core files from $(pwd)..."
    
    # 현재 디렉토리에서 *_libretro.so 파일을 찾습니다.
    local so_file=$(find . -maxdepth 1 -name "*_libretro.so" -print -quit)

    if [[ -n "$so_file" ]]; then
        log_msg INFO "Found core file: $so_file"
        cp -v "$so_file" "$md_inst/"
        log_msg SUCCESS "Core file installed to $md_inst"
    else
        log_msg ERROR "Could not find a compiled .so file in the build directory."
    fi

    # 코어 설치 모듈 내 md_ret_files 배열 전체 복사 지원
    if [[ -n "${md_ret_files[*]}" ]]; then
        for _file in "${md_ret_files[@]}"; do
            # .so 파일은 이미 위에서 복사했으므로 건너뜁니다.
            if [[ "$_file" == *.so ]]; then continue; fi

            if [[ -e "$_file" ]]; then
                if [[ -d "$_file" ]]; then
                    cp -arv "$_file" "$md_inst/"
                    log_msg INFO "Directory installed: $md_inst/$(basename "$_file")"
                else
                    cp -v "$_file" "$md_inst/"
                    log_msg INFO "File installed: $md_inst/$(basename "$_file")"
                fi
            else
                log_msg WARN "File/directory to install not found: $_file"
            fi
        done
    fi
}