#!/usr/bin/env bash
#
# 파일명: helpers.sh
# Retro Pangui Module: Utility and Logging Functions
# ===============================================

# 로그 메시지 출력 및 기록 (호출 위치 정보 추가)
log_msg() {
    local TYPE="$1"
    local MSG="$2"
    # BASH_SOURCE[1] : 함수를 호출한 스크립트 파일 경로
    # BASH_LINENO[0] : 함수가 호출된 라인 번호
    local CALLER_INFO="$(basename "${BASH_SOURCE[1]}"):${BASH_LINENO[0]}"
    local TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    local COLOR_RESET='\033[0m'
    local COLOR=''
    case "$TYPE" in
        STEP)    COLOR='\033[1;34m' ;;
        SUCCESS) COLOR='\033[1;32m' ;;
        INFO)    COLOR='\033[0;37m' ;;
        WARN)    COLOR='\033[1;33m' ;;
        ERROR)   COLOR='\033[1;31m' ;;
        *)       TYPE="DEBUG"; COLOR='\033[0;36m';;
    esac

    # 화면과 로그 파일 양쪽에 호출 위치(파일명:라인번호) 정보를 추가합니다.
    echo -e "${COLOR}[$TYPE]${COLOR_RESET} ($CALLER_INFO) $MSG" >&2
    if [ -n "$LOG_FILE" ]; then
        echo "[$TIMESTAMP] [$TYPE] ($CALLER_INFO) $MSG" >> "$LOG_FILE"
    fi
}

# 명령어 존재여부 확인
command_exists() {
    command -v "$1" >/dev/null 2>&1
}
