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
# config.sh를 source하여 모든 경로와 설정 변수를 로드합니다.
# config.sh는 이 스크립트의 위치를 기준으로 ROOT_DIR을 올바르게 설정합니다.
source "$(dirname "${BASH_SOURCE[0]}")/scriptmodules/config.sh"
source "$MODULES_DIR/helpers.sh"
source "$MODULES_DIR/inifuncs.sh"
source "$MODULES_DIR/version.sh"
source "$MODULES_DIR/ui.sh"
source "$MODULES_DIR/ext_retropie_core.sh"
source "$MODULES_DIR/packages.sh"

# 로그 파일 경로 정의 (helpers.sh가 사용하기 전에 정의)
# 로그 디렉토리는 env.sh를 통해 이미 설정되어 있습니다.
LOG_FILE="$LOG_DIR/retropangui_$(date +%Y%m%d_%H%M%S).log"
export LOG_FILE

exec > >(tee -a "$LOG_FILE") 2>&1

# --- [2] 메인 실행 함수 ---
function main() {
    load_version_from_git

    # 필수 권한 확인
    if [[ "$(id -u)" -ne 0 ]]; then
        echo "❌ 오류: 스크립트는 반드시 'sudo'로 실행되어야 합니다. 예: 'sudo $0'"
        exit 1
    fi
    ensure_log_dir
    # 스크립트 실행 권한 부여
    echo "[$TIMESTAMP] [INFO] (retropangui_setup.sh:39) 자신과 하위 스크립트의 실행 권한 확인 및 부여" >> "$LOG_FILE"
    find "$ROOT_DIR" -type f -name "*.sh" -exec chmod +x {} \;
    echo "[$TIMESTAMP] [SUCCESS] (retropangui_setup.sh:41) 모든 .sh 파일에 실행 권한이 부여되었습니다." >> "$LOG_FILE"

    # UI를 실행할지 여부를 결정하는 플래그
    local run_ui=true
    local args=("$@") # 원본 인자를 복사
    if [[ "${args[0]}" == "--no-ui" ]]; then
        run_ui=false
        args=("${args[@]:1}") # --no-ui 플래그 제거
    fi

    if $run_ui; then
        # 메인 UI 실행
        echo "[$TIMESTAMP] [INFO] (retropangui_setup.sh:44) 🚀 Retro Pangui 설정 관리자를 시작합니다..." >> "$LOG_FILE"
        main_ui "${args[@]}"
        exit 0 # UI가 실행되었을 때만 스크립트를 종료
    else
        echo "[$TIMESTAMP] [INFO] (retropangui_setup.sh:XX) UI 없이 환경만 설정합니다." >> "$LOG_FILE"
        # UI가 실행되지 않으면, install_module이 실행될 수 있도록 종료하지 않고 반환
    fi
}

# --- [3] 스크립트 실행 ---
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ "$1" == "install_module" && -n "$2" && -n "$3" ]]; then
        # 디버깅을 위한 install_module 직접 호출
        main --no-ui # UI 없이 환경만 설정
        install_module "$2" "$3"
    else
        main "$@"
    fi
fi
