#!/usr/bin/env bash

# 파일명: install_base_2_in_5_ra.sh
# Retro Pangui Module: RetroArch Installation (Base 2/5)
# 
# 이 스크립트는 RetroArch를 Git에서 클론하여 빌드하고 설치하는 
# install_retroarch 함수를 정의합니다.
# ===============================================

install_retroarch() {
    log_msg STEP "RetroArch 소스 빌드 및 설치 시작..."

    EXT_FOLDER="$(get_Git_Project_Dir_Name "$RA_GIT_URL")"
    RA_BUILD_DIR="$INSTALL_BUILD_DIR/$EXT_FOLDER"
    log_msg INFO "ℹ️ RetroArch 프로젝트 이름: $EXT_FOLDER"
    log_msg INFO "ℹ️ RetroArch 빌드 디렉토리: $RA_BUILD_DIR"

    log_msg INFO "RetroArch 저장소($RA_GIT_URL) 클론 또는 pull 중..."
    git_Pull_Or_Clone "$RA_GIT_URL" "$RA_BUILD_DIR"

    cd "$RA_BUILD_DIR" \
        || return 1
    
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
        --enable-sdl2 \
            || { log_msg ERROR "RetroArch configure 실패."; return 1; }

    log_msg INFO "RetroArch 빌드 시작 (make -j$(nproc))..."
    make -j$(nproc) \
        || { log_msg ERROR "RetroArch 빌드 실패."; return 1; }
    
    log_msg INFO "RetroArch 설치 중..."
    sudo make install \
        || { log_msg ERROR "RetroArch 설치 실패."; return 1; }
    
    # RetroArch Assets 설치 추가
    log_msg STEP "RetroArch Assets 소스 클론 및 설치 시작..."
    
    EXT_FOLDER_ASSETS="$(get_Git_Project_Dir_Name "$RA_ASSETS_GIT_URL")"
    RA_ASSETS_BUILD_DIR="$INSTALL_BUILD_DIR/$EXT_FOLDER_ASSETS"
    log_msg INFO "ℹ️ RetroArch Assets 프로젝트 이름: $EXT_FOLDER_ASSETS"
    log_msg INFO "ℹ️ RetroArch Assets 빌드 디렉토리: $RA_ASSETS_BUILD_DIR"

    log_msg INFO "RetroArch Assets 저장소($RA_ASSETS_GIT_URL) 클론 또는 pull 중..."
    git_Pull_Or_Clone "$RA_ASSETS_GIT_URL" "$RA_ASSETS_BUILD_DIR"

    cd "$RA_ASSETS_BUILD_DIR" \
        || return 1

    log_msg INFO "RetroArch Assets 설치 중 (PREFIX: $INSTALL_ROOT_DIR)..."
    sudo make PREFIX="$INSTALL_ROOT_DIR" install \
        || { log_msg ERROR "RetroArch Assets 설치 실패."; return 1; }
    
    log_msg SUCCESS "RetroArch Assets 설치 완료. 설치 경로: $INSTALL_ROOT_DIR"
    
    log_msg SUCCESS "RetroArch 빌드 및 설치 완료. 설치 경로: $INSTALL_ROOT_DIR"
    return 0
}

install_retroarch