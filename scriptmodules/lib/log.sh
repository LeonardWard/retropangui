#!/usr/bin/env bash
#
# 파일명: helpers.sh
# Retro Pangui Module: Utility and Logging Functions
# ===============================================

# 로그 레벨 설정 (환경 변수로 제어 가능)
# 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR, 4=SUCCESS, 5=STEP
LOG_LEVEL="${LOG_LEVEL:0}"  # 기본값: INFO (DEBUG 숨김)

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

    # 로그 레벨 매핑
    local LEVEL=1
    case "$TYPE" in
        DEBUG)   LEVEL=0 ;;
        INFO)    LEVEL=1 ;;
        WARN)    LEVEL=2 ;;
        ERROR)   LEVEL=3 ;;
        SUCCESS) LEVEL=4 ;;
        STEP)    LEVEL=5 ;;
    esac

    # 현재 로그 레벨보다 낮으면 출력 안 함
    [[ "$LEVEL" -lt "$LOG_LEVEL" ]] && return

    # 화면 출력
    echo "[$TYPE] ($CALLER_INFO) $MSG" >&2

    # 파일 기록 (모든 레벨 기록)
    if [ -n "$LOG_FILE" ]; then
        echo "[$TIMESTAMP] [$TYPE] ($CALLER_INFO) $MSG" >> "$LOG_FILE"
    fi
}

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

# dialog --gauge를 위한 로깅 및 출력 함수
# 사용법: log_and_gauge <percentage> <message>
function log_and_gauge() {
    local percentage="$1"
    local message="$2"

    # 1. 로그 파일에 기록
    log_msg STEP "$message"

    # 2. whiptail --gauge에 입력으로 전달
    echo "$percentage"
    echo "### $message"
}
