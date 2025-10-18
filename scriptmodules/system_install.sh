#!/usr/bin/env bash
#
# file: system_install.sh
# ==========================================================
# RetroPangui Base System 설치 스크립트 모음 실행기 (안정적 에러 체크 방식)
# ==========================================================

set -e
log_msg "DEBUG" "system_install.sh: Sourced. MODULES_DIR=${MODULES_DIR}"

SUCCESS=1

# # 1. Dependency 설치
# source "$MODULES_DIR/install_base_1_in_5_deps.sh" "$@" || SUCCESS=0

# # 2. RetroArch 설치/설정
# if [ "$SUCCESS" -eq 1 ]; then
#     source "$MODULES_DIR/install_base_2_in_5_ra.sh" "$@" || SUCCESS=0
# fi

# # 3. EmulationStation 설치/설정
# if [ "$SUCCESS" -eq 1 ]; then
#     source "$MODULES_DIR/install_base_3_in_5_es.sh" "$@" || SUCCESS=0
# fi

# 4. 코어 설치/설정
if [ "$SUCCESS" -eq 1 ]; then
    source "$MODULES_DIR/install_base_4_in_5_cores.sh"
    install_base_cores "$@" || SUCCESS=0
fi

# 5. 환경설정, 최종 초기화
if [ "$SUCCESS" -eq 1 ]; then
    source "$MODULES_DIR/install_base_5_in_5_setup_env.sh" "$@" || SUCCESS=0
fi

# 설치 결과 안내
if command -v whiptail >/dev/null 2>&1; then
    if [ "$SUCCESS" -eq 1 ]; then
        whiptail --title "✅ 설치 완료" --msgbox "Base System의 모든 설치 단계가 정상적으로 완료되었습니다." 10 60
    else
        whiptail --title "❌ 설치 실패" --msgbox "설치 중 오류가 발생했습니다.\n로그를 확인 후 다시 시도하십시오." 10 60
    fi
else
    if [ "$SUCCESS" -eq 1 ]; then
        echo "✅ 설치가 정상적으로 완료되었습니다."
    else
        echo "❌ 설치가 실패했습니다."
    fi
fi

exit $((1-SUCCESS))
