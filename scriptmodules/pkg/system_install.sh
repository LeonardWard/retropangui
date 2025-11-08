#!/usr/bin/env bash
#
# file: system_install.sh
# ==========================================================
# RetroPangui Base System 설치 스크립트 모음 실행기 (안정적 에러 체크 방식)
# ==========================================================

# set -e 제거: 각 단계별로 명시적 에러 처리를 하므로 불필요
# 오류 발생 시에도 최종 return까지 도달하여 메인 메뉴로 정상 복귀
log_msg "DEBUG" "system_install.sh: Sourced. MODULES_DIR=${MODULES_DIR}"

# 공용 함수 로드 (check.sh의 설치 확인 함수 사용을 위해 필요)
source "$MODULES_DIR/lib/func.sh"

SUCCESS=1

# 1. Dependency 설치
source "$MODULES_DIR/lib/deps.sh" "$@" || SUCCESS=0

# 2. RetroArch 설치/설정
if [ "$SUCCESS" -eq 1 ]; then
    if is_retroarch_installed; then
        log_msg INFO "RetroArch가 이미 설치되어 있습니다. 설치를 건너뜁니다."
    else
        source "$MODULES_DIR/pkg/retroarch.sh" "$@" || SUCCESS=0
    fi
fi

# 3. EmulationStation 설치/설정
if [ "$SUCCESS" -eq 1 ]; then
    if is_emulationstation_installed; then
        log_msg INFO "EmulationStation이 이미 설치되어 있습니다. 설치를 건너뜁니다."
    else
        source "$MODULES_DIR/pkg/emulationstation.sh" "$@" || SUCCESS=0
    fi
fi

# 4. 코어 설치/설정
if [ "$SUCCESS" -eq 1 ]; then
    source "$MODULES_DIR/pkg/base_cores.sh"
    install_base_cores "$@" || SUCCESS=0
fi

# 5. 환경설정, 최종 초기화
if [ "$SUCCESS" -eq 1 ]; then
    source "$MODULES_DIR/lib/setup.sh" "$@" || SUCCESS=0
fi

# 설치 결과 로그 기록 (다이얼로그는 menu.sh에서 표시)
if [ "$SUCCESS" -eq 1 ]; then
    log_msg SUCCESS "Base System의 모든 설치 단계가 정상적으로 완료되었습니다."
else
    log_msg ERROR "설치 중 오류가 발생했습니다. 로그를 확인하십시오."
fi

# source로 호출되므로 exit 대신 return 사용 (메인 메뉴로 돌아가기 위해)
return $((1-SUCCESS))
