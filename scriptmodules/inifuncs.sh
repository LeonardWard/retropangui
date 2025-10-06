#!/usr/bin/env bash

_ini_file=""
_ini_sep=" = "
_ini_quote="\""

iniConfig() {
    _ini_file="$1"
    _ini_sep="${2:-" = "}"
    _ini_quote="${3:-"\""}"

    # ini 파일이 없다면 생성
    [[ ! -f "$_ini_file" ]] && touch "$_ini_file"
}

iniSet() {
    local section="$1"
    local key="$2"
    local value="$3"
    local file="${4:-$_ini_file}"
    [[ -z "$file" ]] && return 1

    local section_exists=0
    local key_exists=0

    section_exists=$(grep -c "^\[$section\]" "$file")
    if [[ $section_exists -eq 0 ]]; then
        echo "[$section]" >> "$file"
    fi

    key_exists=$(awk '/^\['"$section"'\]/ {a=1} a==1 && $0~/'"^$key$_ini_sep"'/{a=2} END{if(a==2) print 1}' "$file")
    sed -i "/^\[$section\]/,/^$/ {
        /^$key$_ini_sep/ c\\$key${_ini_sep}${_ini_quote}$value${_ini_quote}
    }" "$file"

    if [[ -z "$key_exists" ]]; then
        # 키가 없을 경우 추가
        awk -v section="[$section]" -v key="$key" -v sep="$_ini_sep" -v quote="$_ini_quote" -v value="$value" '
            BEGIN { done=0 }
            $0 == section && done==0 { print; print key sep quote value quote; done=1; next }
            { print }
        ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    fi
}

iniGet() {
    local section="$1"
    local key="$2"
    local file="${3:-$_ini_file}"
    awk -v section="[$section]" -v key="$key" -v sep="$_ini_sep" -v quote="$_ini_quote" '
        $0 == section { f=1; next }
        f && $0 ~ "^\\[" { f=0 }
        f && $0 ~ "^" key sep { sub("^" key sep quote, "", $0); sub(quote "$", "", $0); print $0; exit }
    ' "$file"
}

iniDelKey() {
    local section="$1"
    local key="$2"
    local file="${3:-$_ini_file}"

    sed -i "/^\[$section\]/,/^$/ {
        /^$key$_ini_sep/ d
    }" "$file"
}

iniDelSection() {
    local section="$1"
    local file="${2:-$_ini_file}"

    awk '!block; /^\['"$section"'\]/ { block=1 } block && /^$/ { block=0; next } block { next } { print }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

iniListSections() {
    local file="${1:-$_ini_file}"
    grep "^\[.*\]$" "$file" | sed 's/^\[\(.*\)\]$/\1/'
}

iniListKeys() {
    local section="$1"
    local file="${2:-$_ini_file}"
    awk '/^\['"$section"'\]/ {f=1; next} f && /^[[]/ {f=0} f && /^([^#;].*)=.*$/ { print $1 }' "$file"
}
