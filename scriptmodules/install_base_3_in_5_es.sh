#!/usr/bin/env bash

# 파일명: install_base_3_in_5_es.sh
# Retro Pangui Module: EmulationStation Installation (Base 3/5)
# 
# 이 스크립트는 EmulationStation을 Git에서 클론하여 빌드하고 설치하는 
# install_emulationstation 함수를 정의합니다.
# ===============================================

install_emulationstation() {
    log_msg STEP "EmulationStation 소스 빌드 및 설치 시작..."
    local ES_PROJECT_NAME="$(get_Git_Project_Dir_Name "$ES_GIT_URL")"
    local ES_BUILD_DIR="$INSTALL_BUILD_DIR/$ES_PROJECT_NAME"
    log_msg INFO "ℹ️ EmulationStation 프로젝트 이름: $ES_PROJECT_NAME"
    log_msg INFO "ℹ️ EmulationStation 빌드 디렉토리: $ES_BUILD_DIR"

    log_msg INFO "EmulationStation 저장소($ES_GIT_URL) 클론 또는 pull 중..."
    git_Pull_Or_Clone "$ES_GIT_URL" "$ES_BUILD_DIR"

    log_msg INFO "EmulationStation 소스 초기화 중 (이전 패치 제거)..."
    cd "$ES_BUILD_DIR" && git reset --hard HEAD && git clean -fd

    log_msg INFO "EmulationStation 논리 버튼 매핑 패치 적용 중..."
    patch -p1 -d "$ES_BUILD_DIR" < "$RESOURCES_DIR/patches/es_logical_button_mapping_complete.patch" || { log_msg ERROR "EmulationStation 논리 버튼 매핑 패치 적용 실패."; return 1; }

    log_msg INFO "EmulationStation ShowFolders 기능 패치 적용 중..."
    patch -p1 -d "$ES_BUILD_DIR" < "$RESOURCES_DIR/patches/es_showfolders.patch" || { log_msg ERROR "EmulationStation ShowFolders 패치 적용 실패."; return 1; }

    log_msg INFO "EmulationStation 빌드 디렉토리 초기화 중..."
    rm -rf "$ES_BUILD_DIR/build"
    mkdir -p "$ES_BUILD_DIR/build" || return 1
    cd "$ES_BUILD_DIR/build" || return 1

    log_msg INFO "EmulationStation CMake 설정 중..."
    cmake .. -DCMAKE_INSTALL_PREFIX="$INSTALL_ROOT_DIR" || { log_msg ERROR "EmulationStation CMake 설정 실패."; return 1; }

    log_msg INFO "EmulationStation 빌드 시작 (make -j$(nproc))..."
    make CFLAGS="-Wno-unused-variable" CXXFLAGS="-Wno-unused-variable" -j$(nproc) \
        || { log_msg ERROR "EmulationStation 빌드 실패."; return 1; }

    
    log_msg INFO "EmulationStation 설치 중..."
    sudo make install || { log_msg ERROR "EmulationStation 설치 실패."; return 1; }

    # EmulationStation 설정
    log_msg INFO "EmulationStation 설정 디렉토리 생성 및 Recalbox 설정 적용 중..."
    mkdir -p "$USER_CONFIG_PATH/emulationstation"
    cp -r "$ES_BUILD_DIR/resources" "$USER_CONFIG_PATH/emulationstation/resources" || { log_msg ERROR "EmulationStation 리소스 복사 실패."; return 1; }
    sudo rm -rf "$USER_HOME/.emulationstation"
    ln -s "$USER_CONFIG_PATH/emulationstation" $USER_HOME/.emulationstation  || { log_msg ERROR "EmulationStation 심볼릭 링크 생성 실패."; return 1; }

    chown -R $__user:$__user "$ES_CONFIG_DIR" || return 1

    # systemlist.csv를 기반으로 es_systems.cfg 생성
    log_msg INFO "es_systems.cfg 파일을 생성합니다($ES_CONFIG_DIR/es_systems.cfg)."
    generate_es_systems_cfg_from_csv "$SYSTEMLIST_CSV_PATH" "$ES_CONFIG_DIR/es_systems.cfg"
    cp "$RESOURCES_DIR/es-recalbox/es_input.cfg" "$USER_CONFIG_PATH/emulationstation"
    log_msg SUCCESS "EmulationStation 빌드 및 설치 완료. 설치 경로: "$INSTALL_ROOT_DIR""
    return 0
}

# 스크립트가 호출될 때 자동 실행
install_emulationstation