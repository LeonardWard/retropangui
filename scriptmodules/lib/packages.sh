#!/usr/bin/env bash
#
# 파일명: packages.sh
# 패키지 관리 통합 로더 및 stub 함수들
# ===============================================

# 분할된 파일들 로드
source "$MODULES_DIR/lib/special.sh"
source "$MODULES_DIR/lib/install.sh"
source "$MODULES_DIR/lib/remove.sh"

# depends_on: 필요한 OS 패키지 설치 보장
depends_on() {
    for pkg in "$@"; do
        if ! dpkg -s "$pkg" &> /dev/null; then
            log_msg INFO "패키지 $pkg 설치 중..."
            sudo apt-get install -y "$pkg"
        else
            log_msg INFO "패키지 $pkg 이미 설치됨."
        fi
    done
}

# rpSwap: 빌드 스왑 공간(필요시)
rpSwap() {
    # 실제 swapon/off 등 구현 필요시 확장, 현재는 noop
    true
}

# mkRomDir: ROM 디렉토리 생성(예시)
mkRomDir() {
    local sys="$1"
    local dir="${USER_ROMS_PATH:-$HOME/roms}/$sys"
    mkdir -p "$dir"
}

# addEmulator: 에뮬레이터 시스템에 등록(예시)
addEmulator() {
    local def="$1"
    local id="$2"
    local sys="$3"
    local so_path="$4"
    # 실제 등록 행위는 UI/DB와 연동시 별도 구현 필요
    log_msg INFO "에뮬레이터 등록: $id for $sys ($so_path)"
}

# addSystem: 시스템에 등록(예시)
addSystem() {
    local sys="$1"
    # 시스템별 등록 구체적 구현 필요
    log_msg INFO "시스템 등록: $sys"
}
