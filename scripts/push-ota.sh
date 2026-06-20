#!/bin/bash
# push-ota.sh - OTA squashfs를 로컬 파일서버 디렉토리에 배포
#
# 사용법:
#   bash scripts/push-ota.sh <squashfs 파일경로> [버전]
#
# 버전 미지정 시 git describe 자동 감지
# 예:
#   bash scripts/push-ota.sh buildroot/output/images/retropangui.squashfs 0.12
#   bash scripts/push-ota.sh buildroot/output/images/retropangui.squashfs
#
# 파일서버 디렉토리: ~/scripts/ota-server/
# 파일서버 실행:     bash scripts/serve-ota.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OTA_SERVER_DIR="${HOME}/scripts/ota-server"
DEVICE="${DEVICE:-odroidc5}"

if [ -z "$1" ]; then
    echo "사용법: $0 <squashfs 파일경로> [버전]"
    echo "예:     $0 buildroot/output/images/retropangui.squashfs 0.12"
    exit 1
fi

SQ_FILE="$(realpath "$1")"
if [ ! -f "${SQ_FILE}" ]; then
    echo "ERROR: 파일이 없습니다: ${SQ_FILE}"
    exit 1
fi

# 버전: 2번째 인자 > 파일명에서 추출 > git describe 순으로 결정
if [ -n "$2" ]; then
    VERSION="$2"
else
    # 파일명에서 추출 (retropangui-odroidc5-0.14-1-gabcdef.squashfs → 0.14-1-gabcdef)
    BASENAME="$(basename "${SQ_FILE}" .squashfs)"
    EXTRACTED="${BASENAME##retropangui-${DEVICE}-}"
    if [ -n "${EXTRACTED}" ] && [ "${EXTRACTED}" != "${BASENAME}" ]; then
        VERSION="${EXTRACTED}"
    elif VERSION="$(git -C "${SCRIPT_DIR}" describe --tags 2>/dev/null)"; then
        : # git describe 성공
    else
        VERSION="unknown"
    fi
fi

mkdir -p "${OTA_SERVER_DIR}"

echo ">>> OTA 파일서버 배포 중..."
echo "    버전: ${VERSION}"
echo "    소스: ${SQ_FILE}"
echo "    대상: ${OTA_SERVER_DIR}/"

cp "${SQ_FILE}" "${OTA_SERVER_DIR}/retropangui-${DEVICE}.squashfs"

SQ_SHA256="${SQ_FILE}.sha256"
if [ -f "${SQ_SHA256}" ]; then
    cp "${SQ_SHA256}" "${OTA_SERVER_DIR}/retropangui-${DEVICE}.squashfs.sha256"
else
    echo "    SHA256 계산 중..."
    sha256sum "${OTA_SERVER_DIR}/retropangui-${DEVICE}.squashfs" \
        | awk '{print $1}' \
        > "${OTA_SERVER_DIR}/retropangui-${DEVICE}.squashfs.sha256"
fi

echo "${VERSION}" > "${OTA_SERVER_DIR}/version"

echo ""
echo "============================================"
echo "  OTA 서버 파일 업데이트 완료"
echo "  버전: ${VERSION}"
echo "  크기: $(du -h "${OTA_SERVER_DIR}/retropangui-${DEVICE}.squashfs" | cut -f1)"
echo "  SHA256: $(cat "${OTA_SERVER_DIR}/retropangui-${DEVICE}.squashfs.sha256")"
echo ""
echo "  파일서버가 실행 중이 아니면:"
echo "    bash scripts/serve-ota.sh"
echo "============================================"
