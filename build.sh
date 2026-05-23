#!/bin/bash
# build.sh - 호스트에서 실행하는 빌드 진입점
#
# 사용법:
#   ./build.sh [DEVICE]               # 기기 지정 (기본: odroidc5, 버전은 Git 태그 자동 인식)
#   DEVICE=odroidc5 ./build.sh        # 환경변수로 지정
#   VERSION=1.1.0 ./build.sh odroidc5 # 버전 지정
#   ./build.sh --partial              # 부분 빌드: gamepad-mgr + board 파일 + 이미지 재패킹만
#   ./build.sh odroidc5 --partial     # 기기 지정 + 부분 빌드

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --partial 옵션 파싱
PARTIAL=0
ARGS=()
for arg in "$@"; do
    if [ "$arg" = "--partial" ] || [ "$arg" = "-p" ]; then
        PARTIAL=1
    else
        ARGS+=("$arg")
    fi
done
set -- "${ARGS[@]}"

DEVICE="${1:-${DEVICE:-odroidc5}}"
# 사용자가 주입한 VERSION이 없다면 Git 태그를 조회
if [ -z "${VERSION}" ]; then
    # 현재 커밋에 붙은 태그가 있으면 가져오고, 없으면 가장 가까운 태그 기반으로 이름 생성
    # (Git 저장소가 아니거나 태그가 하나도 없으면 에러 방지를 위해 기본값 1.0.0 사용)
    VERSION=$(git describe --tags --always 2>/dev/null || echo "1.0.0")
fi

echo "============================================"
echo "  RETROPANGUI 빌드 시작"
echo "  기기: ${DEVICE}"
echo "  버전: ${VERSION}"
echo "  모드: $([ $PARTIAL -eq 1 ] && echo '부분 빌드 (gamepad-mgr + 이미지)' || echo '전체 빌드')"
echo "  defconfig: retropangui-${DEVICE}_defconfig"
echo "============================================"

# defconfig 존재 확인
DEFCONFIG="${SCRIPT_DIR}/configs/retropangui-${DEVICE}_defconfig"
if [ ! -f "${DEFCONFIG}" ]; then
    echo "ERROR: defconfig 파일이 없습니다: ${DEFCONFIG}"
    ls "${SCRIPT_DIR}/configs/retropangui-"*"_defconfig" 2>/dev/null \
        | sed 's|.*/retropangui-||; s|_defconfig||' \
        | sed 's/^/  - /'
    exit 1
fi

# board 디렉토리 존재 확인
BOARD_DIR="${SCRIPT_DIR}/board/${DEVICE}"
if [ ! -d "${BOARD_DIR}" ]; then
    echo "ERROR: board 디렉토리가 없습니다: ${BOARD_DIR}"
    exit 1
fi

# 볼륨 마운트 디렉터리 사전 생성 (Docker가 root로 자동생성하면 권한 오류)
mkdir -p "${SCRIPT_DIR}/dl"
mkdir -p "${SCRIPT_DIR}/output"

# Docker 접근 권한 확인 — 빌드 시작 전 실패해야 긴 빌드 도중 멈추지 않음
if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker에 접근할 수 없습니다. 다음 명령어로 권한을 추가하세요:"
    echo "  sudo usermod -aG docker \$USER && newgrp docker"
    exit 1
fi

# ES 테마 디렉토리 (기본값: 스크립트 경로 내의 themes 폴더, THEMES_DIR 환경변수로 오버라이드 가능)
THEMES_DIR="${THEMES_DIR:-${SCRIPT_DIR}/themes}"
if [ ! -d "${THEMES_DIR}" ]; then
    echo "WARNING: 테마 디렉토리가 없습니다: ${THEMES_DIR}"
    echo "  기본 테마 없이 빌드됩니다."
    THEMES_DIR=""
fi

# 전용 바이너리 블롭 확인 (Mali DDK 등)
bash "${SCRIPT_DIR}/scripts/fetch-blobs.sh"

# uboot 사전 shallow clone (전체 히스토리 fetch로 인한 Docker 내 OOM 방지)
# Buildroot는 dl/uboot/git/.git 이 존재하면 fetch만 하고 checkout을 건너뜀
UBOOT_DL="${SCRIPT_DIR}/dl/uboot/git"
if [ ! -d "${UBOOT_DL}/.git" ]; then
    echo "[pre] uboot shallow clone 중 (odroidc5-v2023.01)..."
    git clone --depth=1 -b odroidc5-v2023.01 \
        https://git.odroid.com/yocto/uboot \
        "${UBOOT_DL}"
fi

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
    -v "${SCRIPT_DIR}/buildroot:/home/builder/buildroot" \
    -v "${SCRIPT_DIR}/configs:/home/builder/configs" \
    -v "${SCRIPT_DIR}/board:/home/builder/board" \
    -v "${SCRIPT_DIR}/dl:/home/builder/dl" \
    -v "${SCRIPT_DIR}/output:/home/builder/output" \
    -v "${SCRIPT_DIR}/br2-external:/home/builder/br2-external" \
    ${THEMES_DIR:+-v "${THEMES_DIR}:/home/builder/themes:ro"} \
    retropangui-builder \
    bash /home/builder/buildroot/internal_build.sh

echo "[3/3] 빌드 완료!"
echo "============================================"
echo "최종 이미지: ${SCRIPT_DIR}/output/retropangui-${DEVICE}-${VERSION}.img"
echo "============================================"
echo ""
echo "SD 카드에 플래싱하려면:"
echo "  bash scripts/flash-sd.sh output/retropangui-${DEVICE}-${VERSION}.img"


