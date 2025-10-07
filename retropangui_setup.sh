#!/usr/bin/env bash

# 파일명: retropangui_setup.sh
# Retro Pangui 프로젝트 런처 스크립트
#
# 설명:
# 1. 자신과 모든 하위 .sh 파일에 실행 권한을 부여합니다.
# 2. 경로를 확보하고, 핵심 처리기 retropangui_core.sh를 호출합니다.
#
# 사용법:
# sudo ./retropangui_setup.sh

# --- [1] 스크립트 절대 경로 설정 ---
# 어느 위치에서 실행되든 정확한 경로를 보장합니다.
SCRIPTS_DIR="$(dirname "$0")"
SCRIPTS_DIR="$(cd "$SCRIPTS_DIR" && pwd)"
MODULES_DIR="$SCRIPTS_DIR/scriptmodules"
source "$MODULES_DIR/helpers.sh"

log_msg INFO "ℹ️빌드 스크립트 디렉토리: $SCRIPTS_DIR"

log_msg INFO "자신과 하위 스크립트의 실행 권한 확인 및 부여"
# A. 현재 디렉토리의 모든 .sh 파일에 실행 권한 부여
chmod +x "$SCRIPTS_DIR"/*.sh 2>/dev/null
# B. scriptmodules 폴더 내의 모든 .sh 파일에 실행 권한 부여
if [ -d "$MODULES_DIR" ]; then
    find "$MODULES_DIR" -type f -name "*.sh" -exec chmod +x {} \;
    log_msg INFO "✅ 모든 scriptmodules .sh 파일에 실행 권한이 부여되었습니다."
else
    log_msg ERROR "⚠️ 'scriptmodules' 디렉토리를 찾을 수 없습니다. 핵심 파일이 누락되었을 수 있습니다."
fi

# --- [3] 핵심 처리기 호출 ---
# retropangui_core.sh를 'setup' 모드와 'gui' 인자로 호출하여 whiptail 메뉴를 실행합니다.
log_msg ERROR "🚀 Retro Pangui 설정 관리자를 시작합니다..."
"$SCRIPTS_DIR/retropangui_core.sh" setup gui

# 핵심 처리기 종료 후 프로그램 종료
exit 0