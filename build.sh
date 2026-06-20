#!/bin/bash
# build.sh - 호스트에서 실행하는 빌드 진입점
#
# 사용법:
#   ./build.sh [DEVICE]               # 기기 지정 (기본: odroidc5, 버전은 Git 태그 자동 인식)
#   DEVICE=odroidc5 ./build.sh        # 환경변수로 지정
#   VERSION=1.1.0 ./build.sh odroidc5 # 버전 지정
#   ./build.sh --partial              # 부분 빌드: gamepad-mgr + board 파일 + 이미지 재패킹만
#   ./build.sh odroidc5 --partial     # 기기 지정 + 부분 빌드
#   ./build.sh --ota                  # OTA 빌드: squashfs 파일만 생성 (img 생성 없음)
#   ./build.sh odroidc5 --ota         # 기기 지정 + OTA 빌드

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 옵션 파싱
PARTIAL=0
OTA=0
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --partial|-p) PARTIAL=1 ;;
        --ota|-o)     OTA=1 ;;
        *)            ARGS+=("$arg") ;;
    esac
done
set -- "${ARGS[@]}"

DEVICE="${1:-${DEVICE:-odroidc5}}"
if [ -z "${VERSION}" ]; then
    VERSION=$(git describe --tags --long --always 2>/dev/null || echo "1.0.0")
fi

DEFCONFIG="${SCRIPT_DIR}/configs/retropangui-${DEVICE}_defconfig"
BOARD_DIR="${SCRIPT_DIR}/board/${DEVICE}"

echo "============================================"
echo "  RETROPANGUI 빌드 시작"
echo "  기기: ${DEVICE}"
echo "  버전: ${VERSION}"
echo "  모드: $([ $OTA -eq 1 ] && echo OTA빌드 || { [ $PARTIAL -eq 1 ] && echo 부분빌드 || echo 전체빌드; })"
echo "  defconfig: retropangui-${DEVICE}_defconfig"
echo "============================================"

# ─── 환경 감지 ───────────────────────────────────────────────────
_IS_WSL2=0
grep -qi "microsoft" /proc/version 2>/dev/null && _IS_WSL2=1

_DISTRO=""
_PKG_MGR="unknown"
if [ -f /etc/os-release ]; then
    _DISTRO=$(. /etc/os-release && echo "${ID:-}")
fi
case "${_DISTRO}" in
    ubuntu|debian|linuxmint|pop)     _PKG_MGR="apt" ;;
    fedora|rhel|centos|rocky|almalinux) _PKG_MGR="dnf" ;;
    arch|manjaro|endeavouros)        _PKG_MGR="pacman" ;;
    opensuse*|sles)                  _PKG_MGR="zypper" ;;
    *)  command -v brew &>/dev/null  && _PKG_MGR="brew" ;;
esac

# ─── 사전 조건 확인 ──────────────────────────────────────────────
_PREFLIGHT_OK=1
_pf_err()  { echo "  [ERROR] $*"; _PREFLIGHT_OK=0; }
_pf_warn() { echo "  [WARN]  $*"; }

echo ">>> 사전 조건 확인 중..."
[ "$_IS_WSL2" -eq 1 ] && echo "  환경: WSL2 (${_DISTRO})" || echo "  환경: ${_DISTRO:-unknown} / pkg: ${_PKG_MGR}"

# 필수 CLI 도구
_tool_hint() {
    local tool="$1"
    case "${_PKG_MGR}" in
        apt)
            case "$tool" in
                docker) echo "       설치: sudo apt install -y docker.io && sudo systemctl enable --now docker" ;;
                git)    echo "       설치: sudo apt install -y git" ;;
                awk)    echo "       설치: sudo apt install -y gawk" ;;
                nproc)  echo "       설치: sudo apt install -y coreutils" ;;
            esac ;;
        dnf)
            case "$tool" in
                docker) echo "       설치: sudo dnf install -y docker && sudo systemctl enable --now docker" ;;
                git)    echo "       설치: sudo dnf install -y git" ;;
                awk)    echo "       설치: sudo dnf install -y gawk" ;;
                nproc)  echo "       설치: sudo dnf install -y coreutils" ;;
            esac ;;
        pacman)
            case "$tool" in
                docker) echo "       설치: sudo pacman -S docker && sudo systemctl enable --now docker" ;;
                git)    echo "       설치: sudo pacman -S git" ;;
                awk)    echo "       설치: sudo pacman -S gawk" ;;
                nproc)  echo "       설치: sudo pacman -S coreutils" ;;
            esac ;;
        brew)
            case "$tool" in
                docker) echo "       설치: brew install --cask docker" ;;
                git)    echo "       설치: brew install git" ;;
                awk)    echo "       설치: brew install gawk" ;;
                nproc)  echo "       설치: brew install coreutils" ;;
            esac ;;
        *)
            case "$tool" in
                docker) echo "       설치: https://docs.docker.com/engine/install/" ;;
                *)      echo "       패키지 매니저를 감지하지 못했습니다. $tool 을 수동 설치하세요." ;;
            esac ;;
    esac
}
for _tool in git awk nproc docker; do
    if ! command -v "$_tool" &>/dev/null; then
        _pf_err "$_tool 가 설치되어 있지 않습니다."
        _tool_hint "$_tool"
    fi
done

# defconfig
if [ ! -f "${DEFCONFIG}" ]; then
    _pf_err "defconfig 없음: ${DEFCONFIG}"
    echo "       사용 가능한 기기:"
    ls "${SCRIPT_DIR}/configs/retropangui-"*"_defconfig" 2>/dev/null \
        | sed 's|.*/retropangui-||; s|_defconfig||; s/^/         - /'
fi

# board 디렉토리
[ -d "${BOARD_DIR}" ] || _pf_err "board 디렉토리 없음: ${BOARD_DIR}"

# Dockerfile
[ -f "${SCRIPT_DIR}/Dockerfile" ] || _pf_err "Dockerfile 없음: ${SCRIPT_DIR}/Dockerfile"

# fetch-blobs.sh
[ -f "${SCRIPT_DIR}/scripts/fetch-blobs.sh" ] || _pf_err "scripts/fetch-blobs.sh 없음"

# buildroot (gitignore 제외 대상 — Docker 내부에서 자동 다운로드됨)
[ -f "${SCRIPT_DIR}/buildroot/Makefile" ] || \
    echo "  [INFO]  buildroot 소스 없음 — 첫 빌드 시 Docker 내부에서 자동 다운로드됩니다."

# Docker 접근 (미설치 / daemon 미실행 / 권한 없음 구분)
if command -v docker &>/dev/null; then
    if ! docker info >/dev/null 2>&1; then
        _DOCKER_ERR=$(docker info 2>&1)
        if echo "$_DOCKER_ERR" | grep -qi "permission denied"; then
            _pf_err "Docker 소켓 권한 없음"
            echo "       해결: sudo usermod -aG docker \$USER && newgrp docker"
        elif echo "$_DOCKER_ERR" | grep -qi "cannot connect\|connection refused\|No such file\|Is the docker daemon running"; then
            _pf_err "Docker 데몬이 실행되지 않았습니다"
            if [ "$_IS_WSL2" -eq 1 ]; then
                echo "       해결: sudo service docker start"
            else
                echo "       해결: sudo systemctl start docker"
            fi
        else
            _pf_err "Docker 오류: $(echo "$_DOCKER_ERR" | grep -i 'error\|cannot\|failed' | head -1)"
        fi
    fi
fi

# 디스크 여유 공간 (경고만)
_check_space() {
    local dir="$1" min_gb="$2" label="$3"
    mkdir -p "$dir" 2>/dev/null
    local avail_gb
    avail_gb=$(df -k "$dir" 2>/dev/null | awk 'NR==2{printf "%d", $4/1024/1024}')
    [ -z "$avail_gb" ] && return
    [ "$avail_gb" -lt "$min_gb" ] && \
        _pf_warn "${label} 여유 공간 ${avail_gb}GB (권장 ${min_gb}GB 이상)"
}
_check_space "${SCRIPT_DIR}/output"    10  "output"
_check_space "${SCRIPT_DIR}/buildroot" 40  "buildroot"

# RAM (경고만)
_ram_gb=$(awk '/MemTotal/{printf "%d", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo 0)
[ "$_ram_gb" -lt 4 ] && _pf_warn "RAM ${_ram_gb}GB — 빌드에 최소 4GB 권장"

if [ "$_PREFLIGHT_OK" -eq 0 ]; then
    echo ""
    echo ">>> 사전 조건 미충족으로 빌드를 중단합니다."
    exit 1
fi
echo "  OK"

# 볼륨 마운트 디렉터리 사전 생성 (Docker가 root로 자동생성하면 권한 오류)
mkdir -p "${SCRIPT_DIR}/dl" "${SCRIPT_DIR}/output"

# 전용 바이너리 블롭 확인 (Mali DDK 등)
# (테마는 post-build.sh에서 GitHub에서 자동 다운로드됨)
bash "${SCRIPT_DIR}/scripts/fetch-blobs.sh"

# 대형 git 패키지 사전 shallow clone
# - Buildroot의 git 다운로더는 기본적으로 --depth=1을 사용하도록 패치됨
#   (buildroot/support/download/git + BR2_GIT_FETCH_DEPTH=1)
# - 하지만 첫 빌드 시 Docker 안에서 clone이 시작되면 OOM이 발생할 수 있으므로
#   여기서 미리 dl/ 캐시에 받아두면 Docker 안에서는 fetch(업데이트)만 수행
# - 이미 캐시가 있으면 스킵 (증분 빌드 시 중요)
_shallow_clone() {
    local name="$1" url="$2" branch="$3"
    local dldir="${SCRIPT_DIR}/dl/${name}/git"
    if [ ! -d "${dldir}/.git" ]; then
        echo "[pre] ${name} shallow clone 중 (${branch})..."
        git clone --depth=1 -b "${branch}" "${url}" "${dldir}"
    else
        echo "[pre] ${name} 캐시 존재 (스킵)"
    fi
}

# 서브모듈 포함 대형 패키지는 반드시 여기서 미리 clone
# (git SITE_METHOD이고 서브모듈 있는 것들)
# emulationstation은 버전이 브랜치(main)라서 dl 캐시가 한 번 생기면
# GitHub에 새 커밋을 push해도 재빌드에 반영되지 않음.
# 주의: tarball만 지우면 buildroot가 같은 폴더의 git 캐시에서 fetch 없이
# tarball을 재생성하므로 (낡은 커밋 그대로) git 캐시까지 통째로 삭제해야 함.
# 실제 buildroot 캐시는 buildroot/dl/ 임 (호스트 dl/은 사전 clone 전용).
if [ $PARTIAL -eq 0 ]; then
    echo "[pre] emulationstation 캐시 제거 (최신 main 반영)"
    rm -rf "${SCRIPT_DIR}/dl/emulationstation" \
           "${SCRIPT_DIR}/buildroot/dl/emulationstation" \
           "${SCRIPT_DIR}/buildroot/output/build/emulationstation-main"
fi

_shallow_clone uboot             https://git.odroid.com/yocto/uboot                             odroidc5-v2023.01
_shallow_clone kodi-pangui       https://github.com/xbmc/xbmc                                   21.3-Omega
_shallow_clone retroarch         https://github.com/libretro/RetroArch                          v1.22.2
_shallow_clone retroarch-assets  https://github.com/libretro/retroarch-assets.git              master
_shallow_clone emulationstation  https://github.com/LeonardWard/retropangui-emulationstation    main

# Docker 이미지 빌드
echo "[1/3] Docker 빌드 환경 이미지 생성 중..."
docker build -t retropangui-builder "${SCRIPT_DIR}"

# Docker 컨테이너에서 빌드 실행
echo "[2/3] Buildroot 빌드 시작..."
docker run --rm \
    --cpus="$(nproc)" \
    --memory="$(awk '/MemTotal/{printf "%dm", $2/1024}' /proc/meminfo)" \
    --memory-swap=-1 \
    -e DEVICE="${DEVICE}" \
    -e VERSION="${VERSION}" \
    -e BUILD_JOBS="$(nproc)" \
    -e PARTIAL="${PARTIAL}" \
    -e OTA="${OTA}" \
    -v "${SCRIPT_DIR}/buildroot:/home/builder/buildroot" \
    -v "${SCRIPT_DIR}/configs:/home/builder/configs" \
    -v "${SCRIPT_DIR}/board:/home/builder/board" \
    -v "${SCRIPT_DIR}/dl:/home/builder/dl" \
    -v "${SCRIPT_DIR}/output:/home/builder/output" \
    -v "${SCRIPT_DIR}/br2-external:/home/builder/br2-external" \
    retropangui-builder \
    bash /home/builder/buildroot/internal_build.sh


echo "[3/3] 빌드 완료!"
echo "============================================"
if [ $OTA -eq 1 ]; then
    echo "OTA squashfs: ${SCRIPT_DIR}/output/retropangui-${DEVICE}-${VERSION}.squashfs"
    echo "SHA256:       ${SCRIPT_DIR}/output/retropangui-${DEVICE}-${VERSION}.squashfs.sha256"
    echo ""
    echo "파일서버에 배포하려면:"
    echo "  bash scripts/push-ota.sh output/retropangui-${DEVICE}-${VERSION}.squashfs"
else
    echo "최종 이미지: ${SCRIPT_DIR}/output/retropangui-${DEVICE}-${VERSION}.img"
    echo ""
    echo "SD 카드에 플래싱하려면:"
    echo "  bash scripts/flash-sd.sh output/retropangui-${DEVICE}-${VERSION}.img"
fi
echo "============================================"
