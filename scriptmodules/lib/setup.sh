#!/usr/bin/env bash
#
# 파일명: install_base_5_in_5_setup_env.sh
# Retro Pangui Module: Environment Setup (Base 5/5)
#
# 이 스크립트는 최종 환경 설정을 처리하는
# setup_environment 함수를 정의합니다.
# ===============================================

setup_environment() {
    log_msg STEP "Retro Pangui 환경 설정 시작..."

    local __user="$(get_effective_user)"

    if [[ -z "$__user" ]]; then
        log_msg ERROR "유효 사용자 이름을 결정할 수 없습니다. 권한 처리가 불가능합니다."
        return 1
    fi

    log_msg INFO "유효 사용자 이름: $__user"

    # runcommand_config.sh 스크립트 생성
    create_runcommand_config_script "$ROOT_DIR"

    # runcommand.sh 스크립트 생성
    create_runcommand_script

    # ES 입력 설정 복사
    sudo cp "$ROOT_DIR/resources/es-recalbox/es_input.cfg" "$ES_CONFIG_DIR"

    # 소유권 설정
    set_dir_ownership_and_permissions "$USER_SYSTEM_PATH"

    # USER_SYSTEM_PATH의 소유권을 재귀적으로 변경
    log_msg INFO "/share/system 경로의 소유권($__user:$__user)을 재귀적으로 적용 중..."
    sudo chown -R "$__user":"$__user" "$USER_SYSTEM_PATH"

    log_msg SUCCESS "환경 설정 완료."
    return 0
}

setup_environment
