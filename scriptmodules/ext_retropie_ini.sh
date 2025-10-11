#!/usr/bin/env bash
#
# 파일명: ext_retropie_inst.sh
# RetroPangui Module: RetroPie 호환 환경 변수 정의 모음
#
# RetroPie-Setup 스크립트와의 호환성을 위해 필요한 
# 4. INI 처리 유틸리티
# Based on original RetroPie-Setup inifuncs.sh
# ===============================================

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