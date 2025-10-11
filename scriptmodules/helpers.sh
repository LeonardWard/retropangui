#!/usr/bin/env bash
#
# 파일명: helpers.sh
# Retro Pangui Module: Utility and Logging Functions
# ===============================================
# 로그 메시지 출력 및 기록 (호출 위치 정보 추가)

# 로그 메시지 출력 및 기록 (호출 위치 정보 추가)
# log_msg() {
#     local TYPE="$1"
#     local MSG="$2"
#     # BASH_SOURCE[1] : 함수를 호출한 스크립트 파일 경로
#     # BASH_LINENO[0] : 함수가 호출된 라인 번호
#     local CALLER_INFO="$(basename "${BASH_SOURCE[1]}"):${BASH_LINENO[0]}"
#     local TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
#     local COLOR_RESET="$(tput sgr0)"
#     local COLOR=\'\'
#     case "$TYPE" in
#         STEP)    COLOR="$(tput setaf 5)$(tput bold)" ;;
#         SUCCESS) COLOR="$(tput setaf 2)$(tput bold)" ;;
#         INFO)    COLOR="$(tput setaf 4)" ;;
#         WARN)    COLOR="$(tput setaf 3)$(tput bold)" ;;
#         ERROR)   COLOR="$(tput setaf 1)$(tput bold)" ;;
#         *)       TYPE="DEBUG"; COLOR="$(tput setaf 6)" ;;
#     esac

#     # 화면과 로그 파일 양쪽에 호출 위치(파일명:라인번호) 정보를 추가합니다。
#     echo -e "${COLOR}[$TYPE]${COLOR_RESET} ($CALLER_INFO) $MSG" >&2
#     if [ -n "$LOG_FILE" ]; then
#         echo "[$TIMESTAMP] [$TYPE] ($CALLER_INFO) $MSG" >> "$LOG_FILE"
#     fi
# }

ensure_log_dir() {
    if [ ! -d "$LOG_DIR" ]; then
        sudo mkdir -p "$LOG_DIR"
        log_msg INFO "로그 디렉토리 생성: $LOG_DIR"
    fi
    log_msg INFO "로그 파일 경로 설정 완료: $LOG_FILE"
}

log_msg() {
    local TYPE="$1"
    local MSG="$2"
    local CALLER_INFO="$(basename "${BASH_SOURCE[1]}"):${BASH_LINENO[0]}"
    local TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    # 색상 코드 제거
    # 화면 출력도 색상 없이
    echo "[$TYPE] ($CALLER_INFO) $MSG" >&2

    if [ -n "$LOG_FILE" ]; then
        echo "[$TIMESTAMP] [$TYPE] ($CALLER_INFO) $MSG" >> "$LOG_FILE"
    fi
}

# 명령어 존재여부 확인 및 에러 로그 출력
run_command() {
    local CMD="$1"
    if ! command_exists "$CMD"; then
        log_msg ERROR "'$CMD' 명령어를 찾을 수 없습니다."
        return 127
    fi
    "$CMD"
    local STATUS="$?"
    if [ "$STATUS" -ne 0 ]; then
        log_msg ERROR "'$CMD' 명령 실행 중 오류 발생 (코드: $STATUS)"
        return "$STATUS"
    fi
    return 0
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}