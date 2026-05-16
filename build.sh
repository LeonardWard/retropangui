#!/bin/bash
# build.sh - 호스트에서 실행하는 빌드 진입점
#
# 사용법:
#   ./build.sh [DEVICE]               # 기기 지정 (기본: odroidc5)
#   DEVICE=odroidc5 ./build.sh        # 환경변수로 지정
#   VERSION=1.1.0 ./build.sh odroidc5 # 버전 지정

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEVICE="${1:-${DEVICE:-odroidc5}}"
VERSION="${VERSION:-1.0.0}"

echo "============================================"
echo "  RETROPANGUI 빌드 시작"
echo "  기기: ${DEVICE}"
echo "  버전: ${VERSION}"
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

# ES 테마 디렉토리 (기본값: ~/share/themes, THEMES_DIR 환경변수로 오버라이드 가능)
THEMES_DIR="${THEMES_DIR:-${HOME}/share/themes}"
if [ ! -d "${THEMES_DIR}" ]; then
    echo "WARNING: 테마 디렉토리가 없습니다: ${THEMES_DIR}"
    echo "  nostalgia-pure-lite-ko 테마 없이 빌드됩니다."
    THEMES_DIR=""
fi

# 전용 바이너리 블롭 확인 (Mali DDK 등)
bash "${SCRIPT_DIR}/scripts/fetch-blobs.sh"

# Docker 이미지 빌드
echo "[1/3] Docker 빌드 환경 이미지 생성 중..."
docker build -t retropangui-builder "${SCRIPT_DIR}"

# Docker 컨테이너에서 빌드 실행
echo "[2/3] Buildroot 빌드 시작..."
docker run --rm \
    --cpus="$(nproc)" \
    --memory="$(awk '/MemTotal/{printf "%dm", $2/1024}' /proc/meminfo)" \
    -e DEVICE="${DEVICE}" \
    -e VERSION="${VERSION}" \
    -e BUILD_JOBS="$(nproc)" \
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


