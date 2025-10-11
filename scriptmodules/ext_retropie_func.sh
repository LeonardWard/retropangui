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