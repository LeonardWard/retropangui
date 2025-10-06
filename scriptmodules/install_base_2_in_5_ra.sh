#!/usr/bin/env bash
#
# 파일명: install_base_2_in_5_ra.sh
# Retro Pangui Module: RetroArch Installation (Base 2/5)
# 
# 이 스크립트는 RetroArch를 Git에서 클론하여 빌드하고 설치하는 
# install_retroarch 함수를 정의합니다.

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

install_retroarch() {
    log_msg STEP "RetroArch 소스 빌드 및 설치 시작..."
    
    # 프로젝트 이름 추출 및 디렉터리 결정
    RA_PROJECT_NAME="$(get_git_project_dir_name "$RA_GIT_URL")"
    echo "ℹ️RetroArch 프로젝트 이름: $RA_PROJECT_NAME"
    RA_BUILD_DIR="$INSTALL_BUILD_DIR/$RA_PROJECT_NAME"
    echo "ℹ️RetroArch 빌드 디렉토리: $RA_BUILD_DIR"

    log_msg INFO "RetroArch 저장소($RA_GIT_URL) 클론 중..."
    cd "$INSTALL_BUILD_DIR" || return 1

    if [ -d "$RA_BUILD_DIR" ] && [ "$(ls -A "$RA_BUILD_DIR")" ]; then
        log_msg INFO "RetroArch 빌드 디렉터리가 이미 존재하며, 클론을 건너뜁니다."
    else
        git clone "$RA_GIT_URL" "$RA_BUILD_DIR" || { log_msg ERROR "RetroArch 클론 실패."; return 1; }
    fi

    cd "$RA_BUILD_DIR" || return 1
    
    log_msg INFO "RetroArch 빌드 환경 설정 중..."
    ./configure \
        --prefix="$INSTALL_ROOT_DIR" \
        --disable-x11 \
        --disable-wayland \
        --enable-opengles \
        --enable-udev \
        --enable-alsa \
        --enable-threads \
        --enable-ffmpeg \
        --enable-7zip \
        --enable-sdl2 || { log_msg ERROR "RetroArch configure 실패."; return 1; }

    log_msg INFO "RetroArch 빌드 시작 (make -j$(nproc))..."
    make -j$(nproc) || { log_msg ERROR "RetroArch 빌드 실패."; return 1; }
    
    log_msg INFO "RetroArch 설치 중..."
    sudo make install || { log_msg ERROR "RetroArch 설치 실패."; return 1; }
    
    log_msg SUCCESS "RetroArch 빌드 및 설치 완료."
    return 0
}

# 스크립트가 호출될 때 자동 실행
install_retroarch