#!/usr/bin/env bash

# 파일명: install_base_1_in_5_deps.sh
# Retro Pangui Module: Dependency Installation (Base 1/5)
# 
# 이 스크립트는 Retro Pangui 
# 빌드에 필요한 모든 시스템 패키지 의존성을 설치하는 install_build_dependencies 함수
# 사용자 경로를 생성하는 함수를 정의합니다.
# ===============================================

install_build_dependencies() {
    log_msg STEP "빌드 의존성 패키지 설치 시작..."
    
    log_msg INFO "시스템 패키지 업데이트 중..."
    sudo apt-get update \
        || { log_msg ERROR "apt update 실패."; return 1; }

    log_msg INFO "필수 빌드 의존성 설치 중..."
    sudo apt-get install -y "${BUILD_DEPS[@]}" \
        || { log_msg ERROR "빌드 의존성 설치 실패."; return 1; }

    log_msg SUCCESS "빌드 의존성 설치 완료."
    return 0
}

create_user_paths() {
    local paths=(
        "$USER_SHARE_PATH"
        "$USER_ROMS_PATH"
        "$USER_BIOS_PATH"
        "$USER_SAVES_PATH"
        "$USER_SCREENS_PATH"
        "$USER_MUSIC_PATH"
        "$USER_SPLASH_PATH"
        "$USER_THEMES_PATH"
        "$USER_OVERLAYS_PATH"
        "$USER_CHEATS_PATH"
        "$USER_SYSTEM_PATH"
        "$USER_CONFIG_PATH"
        "$USER_LOGS_PATH"
        "$USER_SCRIPTS_PATH"
    )

    for dir in "${paths[@]}"; do
        if [ -n "$dir" ]; then
            local owner=$(set_dir_ownership_and_permissions "$dir")
            echo "생성됨: $dir (소유자: $owner)"
        fi
    done
}

# 스크립트가 호출될 때 자동 실행
install_build_dependencies
create_user_paths