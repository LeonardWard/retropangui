#!/usr/bin/env bash
#
# 파일명: setup.sh
# Retro Pangui Module: Environment Setup (Base 5/5)
#
# 이 스크립트는 최종 환경 설정을 처리하는
# setup_environment 함수를 정의합니다.
# ===============================================

install_default_themes() {
    log_msg INFO "기본 테마 설치 중..."

    local themes_to_install=("nostalgia-pure-lite-ko" "nostalgia-pure-lite-en")
    
    for theme_name in "${themes_to_install[@]}"; do
        local theme_src="$RESOURCES_DIR/themes/$theme_name"
        local theme_dst="$USER_THEMES_PATH/$theme_name"

        if [[ -d "$theme_dst" ]]; then
            log_msg INFO "테마가 이미 설치되어 있습니다: $theme_dst"
            continue
        fi

        if [[ -d "$theme_src" ]]; then
            set_dir_ownership_and_permissions "$USER_THEMES_PATH" > /dev/null || { log_msg WARN "테마 디렉토리 생성 실패."; }
            cp -r "$theme_src" "$theme_dst" || { log_msg WARN "테마 '$theme_name' 설치 실패 (선택사항)."; continue; }
            set_dir_ownership_and_permissions "$theme_dst" > /dev/null || { log_msg WARN "테마 '$theme_name' 권한 설정 실패."; }
            log_msg SUCCESS "테마 설치 완료: $theme_dst"
        else
            log_msg WARN "테마 소스를 찾을 수 없습니다: $theme_src"
        fi
    done

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

    # 기본 테마 설치 (ES가 이미 설치되어 있어도 실행됨)
    install_default_themes

    # USER_SHARE_PATH 전체의 소유권을 재귀적으로 변경
    log_msg INFO "share 경로 전체의 소유권($__user:$__user)을 재귀적으로 적용 중..."
    sudo chown -R "$__user":"$__user" "$USER_SHARE_PATH"

    log_msg SUCCESS "환경 설정 완료."
    return 0
}

setup_environment
