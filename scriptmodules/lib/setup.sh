#!/usr/bin/env bash
#
# 파일명: install_base_5_in_5_setup_env.sh
# Retro Pangui Module: Environment Setup (Base 5/5)
#
# 이 스크립트는 최종 환경 설정을 처리하는
# setup_environment 함수를 정의합니다.
# ===============================================

install_default_theme() {
    log_msg INFO "기본 테마(nostalgia-pure-lite-ko) 설치 중..."
    local default_theme_src="$RESOURCES_DIR/themes/nostalgia-pure-lite-ko"
    local default_theme_dst="$USER_THEMES_PATH/nostalgia-pure-lite-ko"

    # 이미 설치되어 있으면 건너뛰기
    if [[ -d "$default_theme_dst" ]]; then
        log_msg INFO "기본 테마가 이미 설치되어 있습니다: $default_theme_dst"
        return 0
    fi

    if [[ -d "$default_theme_src" ]]; then
        set_dir_ownership_and_permissions "$USER_THEMES_PATH" > /dev/null || { log_msg WARN "테마 디렉토리 생성 실패."; }
        cp -r "$default_theme_src" "$default_theme_dst" || { log_msg WARN "기본 테마 설치 실패 (선택사항)."; return 1; }
        set_dir_ownership_and_permissions "$default_theme_dst" > /dev/null || { log_msg WARN "기본 테마 권한 설정 실패."; }
        log_msg SUCCESS "기본 테마 설치 완료: $default_theme_dst"
    else
        log_msg WARN "기본 테마를 찾을 수 없습니다: $default_theme_src"
        return 1
    fi

    return 0
}

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
    set_dir_ownership_and_permissions "$ES_CONFIG_DIR" > /dev/null
    sudo cp "$ROOT_DIR/resources/es-recalbox/es_input.cfg" "$ES_CONFIG_DIR"

    # 기본 테마 설치 (ES가 이미 설치되어 있어도 실행됨)
    install_default_theme

    # USER_SHARE_PATH 전체의 소유권을 재귀적으로 변경
    log_msg INFO "share 경로 전체의 소유권($__user:$__user)을 재귀적으로 적용 중..."
    sudo chown -R "$__user":"$__user" "$USER_SHARE_PATH"

    log_msg SUCCESS "환경 설정 완료."
    return 0
}

setup_environment
