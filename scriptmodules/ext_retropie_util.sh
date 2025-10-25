#!/usr/bin/env bash
#
# 파일명: ext_retropie_core.sh
# RetroPangui Module: RetroPie 호환 환경 변수 정의
#
# RetroPie-Setup 스크립트와의 호환성을 위해 필요한 
# 1. 환경 설정 및 기본 유틸
# ===============================================

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

function hasFlag() {
    local string="$1"
    local flag="$2"
    [[ -z "$string" || -z "$flag" ]] && return 1

    if [[ "$string" =~ (^| )$flag($| ) ]]; then
        return 0
    else
        return 1
    fi
}

function isPlatform() {
    local flag="$1"
    if hasFlag "${__platform_flags[*]}" "$flag"; then
        return 0
    fi
    return 1
}

function diffFiles() {
    diff -q "$1" "$2" >/dev/null
    return $?
}

function copyDefaultConfig() {
    local from="$1"
    local to="$2"
    if [[ -f "$to" ]]; then
        if ! diffFiles "$from" "$to"; then
            to+=".rp-dist"
            log_msg INFO "Copying new default configuration to $to"
            cp "$from" "$to"
        fi
    else
        log_msg INFO "Copying default configuration to $to"
        cp "$from" "$to"
    fi
    chown "$__user":"$__group" "$to"
}