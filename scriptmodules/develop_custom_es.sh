#!/usr/bin/env bash

# 파일명: develop_custom_es.sh
# Retro Pangui Module: Custom EmulationStation Development
#
# 이 스크립트는 커스텀 EmulationStation 개발을 위한 환경을 설정하고,
# 소스 코드를 클론하며, 빌드하는 과정을 포함합니다.
# ===============================================

# 개발용 ES 소스 정보
DEV_ES_GIT_URL="https://github.com/RetroPie/EmulationStation.git"
DEV_ES_PROJECT_NAME="emulationstation-retropie-dev"
DEV_ES_BUILD_DIR="$MODULES_DIR/$DEV_ES_PROJECT_NAME"

# 개발용 ES 빌드 및 준비 함수
develop_emulationstation() {
    # 이 스크립트는 다른 스크립트에서 소싱하여 사용하는 것을 가정합니다.
    # 따라서 log_msg, git_Pull_Or_Clone 등의 함수를 사용할 수 있어야 합니다.

    log_msg STEP "커스텀 EmulationStation 개발 환경 준비 시작..."

    # 소스 코드 클론/업데이트
    log_msg INFO "개발용 EmulationStation 저장소($DEV_ES_GIT_URL) 클론 또는 pull 중..."
    git_Pull_Or_Clone "$DEV_ES_GIT_URL" "$DEV_ES_BUILD_DIR"

    # 빌드 디렉토리로 이동
    cd "$DEV_ES_BUILD_DIR" || { log_msg ERROR "빌드 디렉토리로 이동 실패: $DEV_ES_BUILD_DIR"; return 1; }

    # 여기에 소스 코드 수정/패치 로직을 추가할 수 있습니다.
    log_msg INFO "향후 이 부분에 Recalbox 기능 참조/적용을 위한 패치 코드가 추가될 수 있습니다."

    # 빌드 준비
    mkdir -p "$DEV_ES_BUILD_DIR/build" || return 1
    cd "$DEV_ES_BUILD_DIR/build" || return 1

    log_msg INFO "개발용 EmulationStation CMake 설정 중..."
    # 실제 설치는 하지 않으므로, CMAKE_INSTALL_PREFIX는 설정하지 않습니다.
    cmake .. || { log_msg ERROR "개발용 EmulationStation CMake 설정 실패."; return 1; }

    log_msg INFO "개발용 EmulationStation 빌드 시작 (make -j$(nproc))..."
    make clean
    make -j$(nproc) || { log_msg ERROR "개발용 EmulationStation 빌드 실패."; return 1; }

    log_msg SUCCESS "커스텀 EmulationStation 개발 빌드 완료."
    log_msg INFO "소스 위치: $DEV_ES_BUILD_DIR"
    log_msg INFO "빌드 결과물: $DEV_ES_BUILD_DIR/build/emulationstation"

    log_msg INFO "개발용 소스 코드의 소유권을 $__user 사용자에게 부여합니다..."
    chown -R "$__user":"$__user" "$DEV_ES_BUILD_DIR"

    return 0
}

# 이 스크립트는 retropangui_setup.sh에서 필요할 때 호출하기 위한 함수 정의용입니다.
# 직접 실행하는 대신, retropangui_setup.sh에 이 스크립트를 호출하는 메뉴를 추가해야 합니다.
# develop_emulationstation
