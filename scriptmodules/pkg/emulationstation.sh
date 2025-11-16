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

    log_msg INFO "EmulationStation main 브랜치로 전환 중..."
    cd "$ES_BUILD_DIR" && git checkout main && git pull || { log_msg ERROR "EmulationStation main 브랜치 전환 실패."; return 1; }

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

    log_msg INFO "EmulationStation locale 파일 설치 중..."
    sudo mkdir -p /opt/retropangui/share/locale/ko_KR/LC_MESSAGES
    sudo cp "$ES_BUILD_DIR/locale/ko_KR/LC_MESSAGES/emulationstation.mo" /opt/retropangui/share/locale/ko_KR/LC_MESSAGES/ || { log_msg WARN "Locale 파일 설치 실패 (선택사항)."; }

    # EmulationStation 설정
    log_msg INFO "EmulationStation 설정 디렉토리 생성 및 Recalbox 설정 적용 중..."
    local target_user
    target_user="$(set_dir_ownership_and_permissions "$USER_CONFIG_PATH/emulationstation")" || return 1

    cp -r "$ES_BUILD_DIR/resources" "$USER_CONFIG_PATH/emulationstation/resources" || { log_msg ERROR "EmulationStation 리소스 복사 실패."; return 1; }
    sudo rm -rf "$USER_HOME/.emulationstation"
    ln -s "$USER_CONFIG_PATH/emulationstation" $USER_HOME/.emulationstation  || { log_msg ERROR "EmulationStation 심볼릭 링크 생성 실패."; return 1; }

    # es_settings.cfg 생성 (경로 설정)
    log_msg INFO "es_settings.cfg 파일을 생성합니다."
    cat > "$ES_CONFIG_DIR/es_settings.cfg" <<EOF
<?xml version="1.0"?>
<string name="RetroArchPath" value="$RETROARCH_BIN_PATH" />
<string name="LibretroCoresPath" value="$LIBRETRO_CORE_PATH" />
<string name="CoreConfigPath" value="$CORE_CONFIG_PATH" />
EOF
    sudo chown "$target_user":"$target_user" "$ES_CONFIG_DIR/es_settings.cfg"

    # es_systems.xml 빈 파일 생성
    # 시스템과 코어 정보는 install_base_4_in_5_cores.sh에서 install_module() 실행 시 자동 추가됨
    log_msg INFO "es_systems.xml 파일을 생성합니다($ES_CONFIG_DIR/es_systems.xml)."
    cat > "$ES_CONFIG_DIR/es_systems.xml" <<'EOF'
<?xml version="1.0"?>
<systemList>
</systemList>
EOF
    sudo chown "$target_user":"$target_user" "$ES_CONFIG_DIR/es_systems.xml"
    log_msg SUCCESS "es_systems.xml 빈 파일 생성 완료. 시스템 정보는 코어 설치 시 자동 추가됩니다."

    # 기존 테마 링크가 있으면 제거 (심볼릭 링크만 제거, -n 옵션으로 링크 자체 삭제)
    local themes_link="$USER_CONFIG_PATH/emulationstation/themes"
    if [[ -L "$themes_link" ]]; then
        unlink "$themes_link" || rm -f "$themes_link"
    elif [[ -e "$themes_link" ]]; then
        rm -rf "$themes_link"
    fi
    # -n 옵션: 심볼릭 링크를 따라가지 않음 (순환 참조 방지)
    # -f 옵션: 기존 링크가 있으면 덮어쓰기
    ln -sfn "$USER_THEMES_PATH" "$themes_link" || { log_msg ERROR "테마 디렉토리 심볼릭 링크 생성 실패."; return 1; }

    # 기본 테마 설치는 setup_environment()로 이동
    # (ES가 이미 설치된 경우에도 테마가 설치되도록 하기 위함)

    cp "$RESOURCES_DIR/emulationstation/es_input.cfg" "$USER_CONFIG_PATH/emulationstation"
    log_msg SUCCESS "EmulationStation 빌드 및 설치 완료. 설치 경로: "$INSTALL_ROOT_DIR""
    return 0
}

# 스크립트가 호출될 때 자동 실행
install_emulationstation