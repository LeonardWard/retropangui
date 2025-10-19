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
DEV_ES_BUILD_DIR="${MODULES_DIR}/${DEV_ES_PROJECT_NAME}"

# 의존성 패키지 체크 및 설치
check_dev_dependencies() {
    local required_packages=(
        "build-essential"
        "cmake"
        "libsdl2-dev"
        "libboost-system-dev"
        "libboost-filesystem-dev"
        "libboost-date-time-dev"
        "libfreeimage-dev"
        "libfreetype6-dev"
        "libeigen3-dev"
        "libcurl4-openssl-dev"
        "libasound2-dev"
        "libgl1-mesa-dev"
        "git"
    )
    
    log_msg INFO "EmulationStation 빌드 의존성 확인 중..."
    
    local missing_packages=()
    for pkg in "${required_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg"; then
            missing_packages+=("$pkg")
        fi
    done
    
    if [ ${#missing_packages[@]} -gt 0 ]; then
        log_msg INFO "필요한 패키지 설치 중: ${missing_packages[*]}"
        apt-get update || { log_msg ERROR "apt-get update 실패"; return 1; }
        apt-get install -y "${missing_packages[@]}" || { log_msg ERROR "패키지 설치 실패"; return 1; }
    else
        log_msg SUCCESS "모든 의존성 패키지가 이미 설치되어 있습니다."
    fi
    
    return 0
}

# 소스 코드 패치 적용 함수
apply_custom_patches() {
    local patch_dir="${DEV_ES_BUILD_DIR}/custom_patches"
    
    log_msg INFO "커스텀 패치 적용 확인 중..."
    
    if [ -d "$patch_dir" ] && [ -n "$(ls -A "$patch_dir"/*.patch 2>/dev/null)" ]; then
        log_msg INFO "발견된 패치 파일 적용 중..."
        for patch_file in "$patch_dir"/*.patch; do
            log_msg INFO "패치 적용: $(basename "$patch_file")"
            patch -p1 < "$patch_file" || {
                log_msg WARN "패치 적용 실패: $(basename "$patch_file")"
            }
        done
    else
        log_msg INFO "적용할 패치가 없습니다."
    fi
}

# 개발용 ES 빌드 및 준비 함수
develop_emulationstation() {
    # 이 스크립트는 다른 스크립트에서 소싱하여 사용하는 것을 가정합니다.
    # 따라서 log_msg, git_Pull_Or_Clone 등의 함수를 사용할 수 있어야 합니다.

    log_msg STEP "커스텀 EmulationStation 개발 환경 준비 시작..."

    # 의존성 체크
    check_dev_dependencies || {
        log_msg ERROR "의존성 패키지 설치 실패"
        return 1
    }

    # 소스 코드 클론/업데이트
    log_msg INFO "개발용 EmulationStation 저장소($DEV_ES_GIT_URL) 클론 또는 pull 중..."
    git_Pull_Or_Clone "$DEV_ES_GIT_URL" "$DEV_ES_BUILD_DIR" || {
        log_msg ERROR "저장소 클론/업데이트 실패"
        return 1
    }

    # 빌드 디렉토리로 이동
    cd "$DEV_ES_BUILD_DIR" || {
        log_msg ERROR "빌드 디렉토리로 이동 실패: $DEV_ES_BUILD_DIR"
        return 1
    }

    # 커스텀 패치 적용
    apply_custom_patches

    # 빌드 준비
    log_msg INFO "빌드 디렉토리 생성 중..."
    rm -rf "$DEV_ES_BUILD_DIR/build"  # 깨끗한 빌드를 위해 기존 빌드 제거
    mkdir -p "$DEV_ES_BUILD_DIR/build" || {
        log_msg ERROR "빌드 디렉토리 생성 실패"
        return 1
    }
    
    cd "$DEV_ES_BUILD_DIR/build" || {
        log_msg ERROR "빌드 디렉토리 이동 실패"
        return 1
    }

    log_msg INFO "개발용 EmulationStation CMake 설정 중..."
    # 디버그 빌드 옵션 추가 (개발용)
    cmake -DCMAKE_BUILD_TYPE=Debug \
          -DCMAKE_CXX_FLAGS="-g -O0" \
          .. || {
        log_msg ERROR "개발용 EmulationStation CMake 설정 실패."
        return 1
    }

    log_msg INFO "개발용 EmulationStation 빌드 시작 (make -j$(nproc))..."
    make -j$(nproc) || {
        log_msg ERROR "개발용 EmulationStation 빌드 실패."
        return 1
    }

    log_msg SUCCESS "커스텀 EmulationStation 개발 빌드 완료."
    log_msg INFO "소스 위치: $DEV_ES_BUILD_DIR"
    log_msg INFO "빌드 결과물: $DEV_ES_BUILD_DIR/build/emulationstation"

    # 바이너리 실행 권한 설정
    if [ -f "$DEV_ES_BUILD_DIR/build/emulationstation" ]; then
        chmod +x "$DEV_ES_BUILD_DIR/build/emulationstation"
        log_msg SUCCESS "실행 파일 권한 설정 완료"
    fi

    log_msg INFO "개발용 소스 코드의 소유권을 $__user 사용자에게 부여합니다..."
    chown -R "$__user":"$__user" "$DEV_ES_BUILD_DIR" || {
        log_msg WARN "소유권 변경 실패"
    }

    # 빌드 정보 저장
    cat > "$DEV_ES_BUILD_DIR/build_info.txt" <<EOF
빌드 일시: $(date '+%Y-%m-%d %H:%M:%S')
빌드 사용자: $(whoami)
Git 커밋: $(git rev-parse HEAD)
Git 브랜치: $(git rev-parse --abbrev-ref HEAD)
빌드 타입: Debug
EOF

    log_msg SUCCESS "빌드 정보가 build_info.txt에 저장되었습니다."
    
    return 0
}

# 개발용 ES 실행 함수 (테스트용)
run_dev_emulationstation() {
    local binary="$DEV_ES_BUILD_DIR/build/emulationstation"
    
    if [ ! -f "$binary" ]; then
        log_msg ERROR "빌드된 EmulationStation을 찾을 수 없습니다."
        log_msg INFO "먼저 develop_emulationstation 함수를 실행하세요."
        return 1
    fi
    
    log_msg INFO "개발용 EmulationStation 실행 중..."
    log_msg INFO "종료하려면 F4 키를 누르세요."
    
    sudo -u "$__user" "$binary" || {
        log_msg ERROR "EmulationStation 실행 실패"
        return 1
    }
    
    return 0
}

# 개발용 ES 제거 함수
clean_dev_emulationstation() {
    log_msg INFO "개발용 EmulationStation 빌드 정리 중..."
    
    if [ -d "$DEV_ES_BUILD_DIR/build" ]; then
        rm -rf "$DEV_ES_BUILD_DIR/build"
        log_msg SUCCESS "빌드 디렉토리가 정리되었습니다."
    else
        log_msg INFO "정리할 빌드 디렉토리가 없습니다."
    fi
    
    return 0
}

# 이 스크립트는 retropangui_setup.sh에서 필요할 때 호출하기 위한 함수 정의용입니다.
# 직접 실행 시 도움말 표시
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "이 스크립트는 직접 실행할 수 없습니다."
    echo "retropangui_setup.sh에서 소싱하여 사용하세요."
    echo ""
    echo "사용 가능한 함수:"
    echo "  - develop_emulationstation       : 개발 환경 빌드"
    echo "  - run_dev_emulationstation       : 개발 버전 실행"
    echo "  - clean_dev_emulationstation     : 빌드 정리"
    echo "  - check_dev_dependencies         : 의존성 확인"
    exit 1
fi