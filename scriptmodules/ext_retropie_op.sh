#!/usr/bin/env bash
#
# 파일명: ext_retropie_op.sh
# RetroPangui Module: RetroPie 호환 환경 변수 정의 모음
#
# RetroPie-Setup 스크립트와의 호환성을 위해 필요한 
# 2. RetroPie 설치 동작 함수
# ===============================================

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

function rp_isInstalled() {
    return 1 # 1 indicates 'not installed'
}