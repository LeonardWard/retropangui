#!/usr/bin/env bash

# 파일명: install_base_2_in_5_ra.sh
# Retro Pangui Module: RetroArch Installation (Base 2/5)
# 
# 이 스크립트는 RetroArch를 Git에서 클론하여 빌드하고 설치하는 
# install_retroarch 함수를 정의합니다.
# ===============================================

install_retroarch() {
    # RetroArch 본체 설치
    log_msg STEP "RetroArch 소스 빌드 및 설치 시작..."
    local EXT_FOLDER="$(get_Git_Project_Dir_Name "$RA_GIT_URL")"
    local RA_BUILD_DIR="$INSTALL_BUILD_DIR/$EXT_FOLDER"
    log_msg INFO "ℹ️ RetroArch 프로젝트 이름: $EXT_FOLDER"
    log_msg INFO "ℹ️ RetroArch 빌드 디렉토리: $RA_BUILD_DIR"

    log_msg INFO "RetroArch 저장소($RA_GIT_URL) 클론 또는 pull 중..."
    git_Pull_Or_Clone "$RA_GIT_URL" "$RA_BUILD_DIR"
    # chown -R $__user:$__user "$RA_BUILD_DIR" || return 1

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
    make clean
    make -j$(nproc) \
        || { log_msg ERROR "RetroArch 빌드 실패."; return 1; }
    
    log_msg INFO "RetroArch 설치 중..."
    sudo make install \
        || { log_msg ERROR "RetroArch 설치 실패."; return 1; }
    
    # 기존 링크 또는 디렉토리가 있다면 제거하여 올바른 심볼릭 링크 생성을 보장
    sudo rm -rf "$RA_CONFIG_DIR"

    # RetroArch 설정
    log_msg INFO "RetroArch 설정 파일 복사 및 패치 (ln -s "$RA_CONFIG_PATH" "$RA_CONFIG_DIR") 중..."
    ln -s "$RA_CONFIG_PATH" "$RA_CONFIG_DIR" || return 1
    sudo chown -R "$__user":"$__user" "$RA_CONFIG_DIR" || return 1

    local CONFIG_RA_SKELETON="$INSTALL_ROOT_DIR/etc/retroarch.cfg"
    if [ -f "$CONFIG_RA_SKELETON" ]; then
        cp "$CONFIG_RA_SKELETON" "$USER_CONFIG_PATH/retroarch.cfg" || { log_msg ERROR "RetroArch 설정 파일 복사 실패."; return 1; }
        # chown -R $__user:$__user "$USER_CONFIG_PATH/retroarch.cfg" || return 1
        log_msg INFO "기본 ($USER_CONFIG_PATH/retroarch.cfg) 복사 완료."
    else
        log_msg WARN "Recalbox retroarch.cfg 템플릿을 찾을 수 없습니다. (경로: $CONFIG_RA_SKELETON)"
    fi
    
    # RetroArch 구성요소 설치 (Assets, Joypads, 등)
    log_msg STEP "RetroArch 추가 구성요소 설치 시작..."

    # 설치할 구성요소 목록 (이름:설치될하위디렉토리:Git주소)
    local ra_components
    ra_components=(
        "Assets:assets:$RA_ASSETS_GIT_URL"
        "Joypad Autoconfigs:autoconfig:$RA_JOYPAD_AUTOCONFIG_GIT_URL"
        "Info:info:$RA_CORE_INFO_GIT_URL"
        "Database:database:$RA_DATABASE_GIT_URL"
        "Overlays:overlays:$RA_OVERLAYS_GIT_URL"
        "Shaders:shaders:$RA_SHADERS_GIT_URL"
    )

    for component_data in "${ra_components[@]}"; do
        IFS=':' read -r name subdir url <<< "$component_data"
        
        local target_path="$USER_CONFIG_PATH/retroarch/$subdir"
        local link_path="$RA_CONFIG_DIR/$subdir"

        # 실제 데이터가 저장될 디렉터리 생성
        sudo mkdir -p "$target_path"

        # 새로운 공용 함수를 사용하여 구성요소 설치
        install_ra_component "$name" "$url" "$target_path" || return 1
    done

    # RetroArch 설정 디렉토리의 소유권을 유효 사용자로 변경
    sudo chown -R "$__user":"$__user" "$USER_CONFIG_PATH/retroarch"

    cp "$INSTALL_ROOT_DIR/etc/retroarch.cfg" "$INSTALL_ROOT_DIR/etc/retroarch.cfg.origin"
    log_msg INFO "복사 완료: $INSTALL_ROOT_DIR/etc/retroarch.cfg.origin"
    cp "$RESOURCES_DIR/retroarch.init.cfg" "$INSTALL_ROOT_DIR/etc/retroarch.cfg"
    log_msg INFO "복사 완료: $INSTALL_ROOT_DIR/etc/retroarch.cfg"

    log_msg SUCCESS "RetroArch 빌드 및 설치 완료: $INSTALL_ROOT_DIR"
    return 0
}

install_retroarch