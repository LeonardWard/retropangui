#!/usr/bin/env bash
#
# 파일명: install_base_3_in_5_emustation.sh
# Retro Pangui Module: EmulationStation Installation (Base 3/5)
# 
# 이 스크립트는 EmulationStation을 Git에서 클론하여 빌드하고 설치하는 
# install_emulationstation 함수를 정의합니다.

SCRIPT_DIR="$(dirname "$0")"
SCRIPT_DIR="$(cd "$SCRIPT_DIR" && pwd)"
echo "ℹ️빌드 스크립트 디렉토리: $SCRIPT_DIR"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/helpers.sh"

# 저장소 URL에서 프로젝트(폴더)명 추출 함수
get_git_project_dir_name() {
    local url="$1"
    local name="$(basename "$url")"
    # .git 확장자 제거
    name="${name%.git}"
    echo "$name"
}

install_emulationstation() {
    log_msg STEP "EmulationStation 소스 빌드 및 설치 시작..."

    # 프로젝트 이름 추출 및 디렉터리 결정
    ES_PROJECT_NAME="$(get_git_project_dir_name "$ES_GIT_URL")"
    echo "ℹ️ EmulationStation 프로젝트 이름: $ES_PROJECT_NAME"
    ES_BUILD_DIR="$INSTALL_BUILD_DIR/$ES_PROJECT_NAME"
    echo "ℹ️ EmulationStation 빌드 디렉토리: $ES_BUILD_DIR"

    log_msg INFO "EmulationStation 저장소($ES_GIT_URL) 클론 중..."
    cd "$INSTALL_BUILD_DIR" || return 1

    if [ -d "$ES_BUILD_DIR" ] && [ "$(ls -A "$ES_BUILD_DIR")" ]; then
        log_msg INFO "EmulationStation 빌드 디렉터리가 이미 존재하며, 클론을 건너뜁니다."
    else
        git clone "$ES_GIT_URL" "$ES_BUILD_DIR" || { log_msg ERROR "EmulationStation 클론 실패."; return 1; }
    fi

    mkdir -p "$ES_BUILD_DIR/build" || return 1
    cd "$ES_BUILD_DIR/build" || return 1
    
    log_msg INFO "EmulationStation CMake 설정 중..."
    cmake .. -DCMAKE_INSTALL_PREFIX="$INSTALL_ROOT_DIR" || { log_msg ERROR "EmulationStation CMake 설정 실패."; return 1; }
    
    log_msg INFO "EmulationStation 빌드 시작 (make -j$(nproc))..."
    make -j$(nproc) || { log_msg ERROR "EmulationStation 빌드 실패."; return 1; }
    
    log_msg INFO "EmulationStation 설치 중..."
    sudo make install || { log_msg ERROR "EmulationStation 설치 실패."; return 1; }

    cp -r ../resources ~/.emulationstation/.

    log_msg SUCCESS "EmulationStation 빌드 및 설치 완료."
    return 0
}

# 스크립트가 호출될 때 자동 실행
install_emulationstation