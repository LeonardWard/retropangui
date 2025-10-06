#!/usr/bin/env bash

# Minimal packages.sh for Retro Pangui

# isPlatform: 시스템 아키/플랫폼을 체크
isPlatform() {
    case "$1" in
        "x86") [[ "$(uname -m)" =~ "x86_64|i686|i386" ]];;
        "arm") [[ "$(uname -m)" =~ "arm"|"aarch64" ]];;
        *) return 1;;
    esac
}

# depends_on: 필요한 OS 패키지 설치 보장
depends_on() {
    for pkg in "$@"; do
        if ! dpkg -s "$pkg" &> /dev/null; then
            echo "[INFO] 패키지 $pkg 설치 중..."
            sudo apt-get install -y "$pkg"
        else
            echo "[INFO] 패키지 $pkg 이미 설치됨."
        fi
    done
}

# gitPullOrClone: 소스 디렉터리 없으면 clone, 있으면 pull
gitPullOrClone() {
    local repo="$1"
    local dir="$2"
    if [ -d "$dir" ]; then
        echo "[INFO] $dir 이미 존재. git pull 진행."
        git -C "$dir" pull
    else
        echo "[INFO] $dir 없음. git clone 진행."
        git clone "$repo" "$dir"
    fi
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
    echo "[INFO] 에뮬레이터 등록: $id for $sys ($so_path)"
}

# addSystem: 시스템에 등록(예시)
addSystem() {
    local sys="$1"
    # 시스템별 등록 구체적 구현 필요
    echo "[INFO] 시스템 등록: $sys"
}
