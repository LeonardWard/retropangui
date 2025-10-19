#!/usr/bin/env bash
#
# 파일명: ext_retropie_func.sh
# RetroPangui Module: RetroPie 호환 환경 변수 정의
#
# RetroPie-Setup 스크립트와의 호환성을 위해 필요한 환경 변수들을 여기에 정의합니다.
# ===============================================

get_Install_Path() {
    local CORE_SCRIPT_PATH="$1"
    local FOLDER="$(basename "$(dirname "$CORE_SCRIPT_PATH")")"
    local ID="$(basename "$CORE_SCRIPT_PATH" .sh)"
    echo "$INSTALL_ROOT_DIR/$FOLDER/$ID"
}

function installLibretroCore() {
    local build_dir="$1"
    local core_id="$2"
    local install_dest_dir="$3"

    if [[ -z "$md_ret_files" ]]; then
        log_msg ERROR "md_ret_files is not set for $core_id"
        return 1
    fi

    for file in "${md_ret_files[@]}"; do
        if [[ -f "$build_dir/$file" ]]; then
            cp "$build_dir/$file" "$install_dest_dir/"
        else
            log_msg WARN "File not found, skipping: $build_dir/$file"
        fi
    done
}