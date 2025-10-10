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
    local system="$1"
    local dest_config="$USER_CONFIG_PATH/$system/retroarch.cfg"
    local src_config="$INSTALL_ROOT_DIR/etc/retroarch.cfg"

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

# =================================================
# INI File Functions
# Based on original RetroPie-Setup inifuncs.sh
# =================================================

# @fn iniConfig()
# @param delim ini file delimiter eg. ' = '
# @param quote ini file quoting character eg. '"'
# @param config ini file to edit
# @brief Configure an ini file for getting/setting values with `iniGet` and `iniSet`
function iniConfig() {
    __ini_cfg_delim="$1"
    __ini_cfg_quote="$2"
    __ini_cfg_file="$3"
}

# @fn iniProcess()
# @param command `set`, `unset` or `del`
# @param key ini key to operate on
# @param value to set
# @param file optional file to use another file than the one configured with iniConfig
# @brief The main function for setting and deleting from ini files - usually
# not called directly but via iniSet iniUnset and iniDel
function iniProcess() {
    local cmd="$1"
    local key="$2"
    local value="$3"
    local file="$4"
    [[ -z "$file" ]] && file="$__ini_cfg_file"
    local delim="$__ini_cfg_delim"
    local quote="$__ini_cfg_quote"

    [[ -z "$file" ]] && fatalError "No file provided for ini/config change"
    [[ -z "$key" ]] && fatalError "No key provided for ini/config change on $file"

    # we strip the delimiter of spaces, so we can "fussy" match existing entries that have the wrong spacing
    local delim_strip=${delim// /}
    # if the stripped delimiter is empty - such as in the case of a space, just use the delimiter instead
    [[ -z "$delim_strip" ]] && delim_strip="$delim"
    local match_re="^[[:space:]#]*$key[[:space:]]*$delim_strip.*$"

    local match
    if [[ -f "$file" ]]; then
        match=$(grep -i "$match_re" "$file" | tail -1)
    else
        touch "$file"
    fi

    if [[ "$cmd" == "del" ]]; then
        [[ -n "$match" ]] && sed -i --follow-symlinks "\|$(sedQuote "$match")|d" "$file"
        return 0
    fi

    [[ "$cmd" == "unset" ]] && key="# $key"

    local replace="$key$delim$quote$value$quote"
    if [[ -z "$match" ]]; then
        # make sure there is a newline then add the key-value pair
        sed -i --follow-symlinks '$a\'
        echo "$replace" >> "$file"
    else
        # replace existing key-value pair
        sed -i --follow-symlinks "s|$(sedQuote "$match")|$(sedQuote "$replace")|g" "$file"
    fi

    return 0
}

# @fn iniUnset()
# @param key ini key to operate on
# @param value to Unset (key will be commented out, but the value can be changed also)
# @param file optional file to use another file than the one configured with iniConfig
# @brief Unset (comment out) a key / value pair in an ini file.
function iniUnset() {
    iniProcess "unset" "$1" "$2" "$3"
}

# @fn iniSet()
# @param key ini key to operate on
# @param value to set
# @param file optional file to use another file than the one configured with iniConfig
# @brief Set a key / value pair in an ini file.
function iniSet() {
    iniProcess "set" "$1" "$2" "$3"
}

# @fn iniDel()
# @param key ini key to operate on
# @param file optional file to use another file than the one configured with iniConfig
# @brief Delete a key / value pair in an ini file.
function iniDel() {
    iniProcess "del" "$1" "" "$2"
}

# @fn iniGet()
# @param key ini key to get the value of
# @param file optional file to use another file than the one configured with iniConfig
# @brief Get the value of a key from an ini file.
function iniGet() {
    local key="$1"
    local file="$2"
    [[ -z "$file" ]] && file="$__ini_cfg_file"
    if [[ ! -f "$file" ]]; then
        ini_value=""
        return 1
    fi

    local delim="$__ini_cfg_delim"
    local quote="$__ini_cfg_quote"
    # we strip the delimiter of spaces, so we can "fussy" match existing entries that have the wrong spacing
    local delim_strip=${delim// /}
    # if the stripped delimiter is empty - such as in the case of a space, just use the delimiter instead
    [[ -z "$delim_strip" ]] && delim_strip="$delim"

    # create a regexp to match the value based on whether we are looking for quotes or not
    local value_m
    if [[ -n "$quote" ]]; then
        value_m="$quote*\([^$quote|\r]*\)$quote*"
    else
        value_m="\([\r]*\)"
    fi

    ini_value="$(sed -n "s#^[ |\t]*$key[ |\t]*$delim_strip[ |\t]*$value_m.*#\1#p" "$file" | tail -1)"
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

    export md_build="$INSTALL_BUILD_DIR/core_build"
    export md_inst="$LIBRETRO_CORE_PATH"
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
    local build_dir="$1"
    local module_id="$2" # 새로 추가된 인자: 코어 ID

    if [[ -z "$build_dir" || ! -d "$build_dir" ]]; then
        log_msg ERROR "installLibretroCore: Invalid build directory provided."
        return 1
    fi
    if [[ -z "$module_id" ]]; then
        log_msg ERROR "installLibretroCore: Module ID not provided."
        return 1
    fi

    log_msg INFO "Installing files for $module_id from $build_dir..."

    if [[ -n "${md_ret_files[*]}" ]]; then
        for _file in "${md_ret_files[@]}"; do
            local src_path="$build_dir/$_file"
            local dest_dir=""
            local file_extension="${_file##*.}" # 파일 확장자 추출
            local file_basename="${_file##*/}" # 파일 이름 추출

            if [[ ! -e "$src_path" ]]; then
                log_msg WARN "File/directory to install not found: $src_path"
                continue
            fi

            # 파일 종류에 따라 목적지 결정
            case "$file_extension" in
                so) # Libretro 코어 파일
                    dest_dir="$md_inst"
                    ;;
                md|txt|chm|html) # 문서 파일
                    dest_dir="$INSTALL_ROOT_DIR/docs/$module_id"
                    ;;
                *) # 그 외 파일 (폴더 포함)
                    if [[ -d "$src_path" ]]; then
                        # 'metadata', 'dats', 'Databases', 'Machines' 같은 폴더
                        dest_dir="$biosdir/$module_id"
                    else
                        # 기본값: 코어 설치 폴더
                        dest_dir="$md_inst"
                    fi
                    ;;
            esac

            # 목적지 디렉터리 생성 (mkUserDir 함수 사용)
            mkUserDir "$dest_dir"

            log_msg INFO "Copying $src_path to $dest_dir"
            cp -Rvf "$src_path" "$dest_dir"
        done
        log_msg SUCCESS "All files for $module_id installed to their respective locations."
    else
        log_msg INFO "No files listed in md_ret_files for $module_id. Nothing to install."
    fi
}

function mkUserDir() {
    mkdir -p "$1"
    chown "$__user":"$__group" "$1"
}

function setRetroArchCoreOption() {
    local option="$1"
    local value="$2"
    iniConfig " = " "\"" "$configdir/all/retroarch-core-options.cfg"
    iniGet "$option"
    if [[ -z "$ini_value" ]]; then
        iniSet "$option" "$value"
    fi
    chown "$__user":"$__group" "$configdir/all/retroarch-core-options.cfg"
}
