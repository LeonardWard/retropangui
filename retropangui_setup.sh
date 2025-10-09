#!/usr/bin/env bash

# =======================================================
# Retro Pangui Setup
# 파일명: retropangui_setup.sh
# 설명: Retro Pangui 프로젝트의 메인 런처 스크립트입니다.
#       모든 환경 변수를 설정하고, 필요한 모듈을 로드한 후,
#       메인 UI를 실행합니다.
# 사용법: sudo ./retropangui_setup.sh
# =======================================================

# --- [1] 환경 설정 및 모듈 로드 ---
# env.sh를 source하여 모든 경로와 설정 변수를 로드합니다.
# env.sh는 이 스크립트의 위치를 기준으로 ROOT_DIR을 올바르게 설정합니다.
source "$(dirname "$0")/scriptmodules/env.sh"

# 기능 라이브러리를 로드합니다.
source "$MODULES_DIR/helpers.sh"
source "$MODULES_DIR/ui.sh"

# --- [2] 메인 실행 함수 ---
function main() {
    # 필수 권한 확인
    if [[ "$(id -u)" -ne 0 ]]; then
        echo "❌ 오류: 스크립트는 반드시 'sudo'로 실행되어야 합니다. 예: 'sudo $0'"
        exit 1
    fi

    # 로그 파일 경로 재정의 (helpers.sh의 기본값을 덮어쓰기)
    # 로그 디렉토리는 install_core_dependencies에서 생성되므로 여기서는 경로만 정의
    LOG_FILE="$LOG_DIR/retropangui_$(date +%Y%m%d_%H%M%S).log"

    # 스크립트 실행 권한 부여
    log_msg INFO "자신과 하위 스크립트의 실행 권한 확인 및 부여"
    find "$ROOT_DIR" -type f -name "*.sh" -exec chmod +x {} \;
    log_msg SUCCESS "모든 .sh 파일에 실행 권한이 부여되었습니다."

    # 메인 UI 실행
    log_msg INFO "🚀 Retro Pangui 설정 관리자를 시작합니다..."
    main_ui "$@"

    exit 0
}

# --- [3] 스크립트 실행 ---
main "$@"
