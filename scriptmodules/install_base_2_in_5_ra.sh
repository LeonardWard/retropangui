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
source "$SCRIPT_DIR/func.sh"

# gitPullOrClone 함수는 반드시 helpers.sh 또는 공용 함수 모듈에 아래처럼 작성되어 있어야 합니다.
# 인자: 저장소 URL, 디렉토리
# 필요 시 옵션 추가 제공 방식도 좋습니다.

# install_retroarch 함수 내부 변경:
install_retroarch() {
    log_msg STEP "RetroArch 소스 빌드 및 설치 시작..."

    EXT_FOLDER="$(get_Git_Project_Dir_Name "$RA_GIT_URL")"
    RA_BUILD_DIR="$INSTALL_BUILD_DIR/$EXT_FOLDER"
    echo "ℹ️ RetroArch 프로젝트 이름: $EXT_FOLDER"
    echo "ℹ️ RetroArch 빌드 디렉토리: $RA_BUILD_DIR"

    log_msg INFO "RetroArch 저장소($RA_GIT_URL) 클론 또는 pull 중..."
    git_Pull_Or_Clone "$RA_GIT_URL" "$RA_BUILD_DIR"

    cd "$RA_BUILD_DIR" 
    || return 1
    
    log_msg INFO "RetroArch 빌드 환경 설정 중..."
    ./configure \
        --prefix="$INSTALL_ROOT_DIR" \
        --disable-x11 \
        --disable-wayland \
        --disable-cg \
        --enable-opengles \
        --enable-udev \
        --enable-alsa \
        --enable-threads \
        --enable-ffmpeg \
        --enable-7zip \
        --enable-sdl2 
        || { log_msg ERROR "RetroArch configure 실패."; return 1; }

    log_msg INFO "RetroArch 빌드 시작 (make -j$(nproc))..."
    make -j$(nproc) 
    || { log_msg ERROR "RetroArch 빌드 실패."; return 1; }
    
    log_msg INFO "RetroArch 설치 중..."
    sudo make install 
    || { log_msg ERROR "RetroArch 설치 실패."; return 1; }
    
    log_msg SUCCESS "RetroArch 빌드 및 설치 완료."
    return 0
}


# 스크립트가 호출될 때 자동 실행
install_retroarch