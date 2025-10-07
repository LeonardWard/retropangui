#!/usr/bin/env bash
#
# 파일명: helpers.sh
# Retro Pangui Module: Utility and Logging Functions

LOG_FILE="$SCRIPTS_DIR/log/retropangui_setup.log"

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

# 필수 도구 점검/설치
check_and_install_prerequisites() {
    log_msg STEP "필수 도구(Git, Whiptail) 확인 및 설치 중..."
    local PREREQS=("git" "whiptail")
    local INSTALL_NEEDED=0
    for CMD in "${PREREQS[@]}"; do
        if ! command_exists "$CMD"; then
            log_msg INFO "$CMD 명령어(가) 없음. 설치 시도."
            INSTALL_NEEDED=1
        fi
    done
    if [ "$INSTALL_NEEDED" -eq 1 ]; then
        log_msg INFO "시스템 패키지 업데이트 중..."
        sudo apt update || { log_msg ERROR "apt update 실패."; return 1; }
        log_msg INFO "필수 도구 설치 중..."
        sudo apt install -y "${PREREQS[@]}" || { log_msg ERROR "필수 도구 설치 실패."; return 1; }
        log_msg SUCCESS "필수 도구 설치 완료."
    else
        log_msg SUCCESS "필수 도구 설치 필요 없음."
    fi
    return 0
}

# 빌드 의존성 패키지 설치 함수 (공통화)
install_build_dependencies() {
    log_msg STEP "빌드 의존성 패키지 설치 시작..."
    log_msg INFO "시스템 패키지 업데이트 중..."
    sudo apt update || { log_msg ERROR "apt update 실패."; return 1; }
    log_msg INFO "필수 빌드 의존성 설치 중..."
    sudo apt install -y "${BUILD_DEPS[@]}" || { log_msg ERROR "빌드 의존성 설치 실패."; return 1; }
    log_msg SUCCESS "빌드 의존성 설치 완료."
    return 0
}
