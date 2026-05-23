#!/bin/bash
# fetch-blobs.sh - Mali DDK 전용 바이너리 다운로드 스크립트
#
# ARM Mali-G310 Valhall DDK는 ARM 전용 라이선스로 인해 공개 저장소에 포함할 수 없습니다.
# Hardkernel 공식 Yocto 레이어(meta-odroid-aml)의 tarball에서 추출합니다.
#
# 사용법:
#   bash scripts/fetch-blobs.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BLOBS_DIR="${SCRIPT_DIR}/../board/odroidc5/blobs/mali"
WORK_DIR="$(mktemp -d)"
trap "rm -rf ${WORK_DIR}" EXIT

TARBALL_URL="https://raw.githubusercontent.com/mdrjr/meta-odroid-aml/master/recipes-graphics/libmali-odroid-c5/files/tarball.tar.bin"

echo "========================================"
echo "  RETROPANGUI-C5 Mali DDK 블롭 다운로드"
echo "========================================"

if [ -f "${BLOBS_DIR}/libMali.so" ]; then
    echo "[OK] Mali blobs already present: ${BLOBS_DIR}/libMali.so"
    echo "     강제 재다운로드: rm -rf ${BLOBS_DIR} && bash scripts/fetch-blobs.sh"
    exit 0
fi

mkdir -p "${BLOBS_DIR}/lib/firmware" "${BLOBS_DIR}/vulkan"

# tarball은 ~100MB. 네트워크 상태에 따라 수분 소요될 수 있음
echo "[1/3] 다운로드 중..."
echo "  출처: github.com/mdrjr/meta-odroid-aml (master)"
curl -fL --progress-bar --connect-timeout 30 \
    -o "${WORK_DIR}/tarball.tar.bin" "${TARBALL_URL}"

echo "[2/3] 추출 중..."
# tarball 내부 경로는 Yocto ${D} 기준 (usr/lib/..., lib/firmware/...) 구조
mkdir -p "${WORK_DIR}/extract"
tar xf "${WORK_DIR}/tarball.tar.bin" -C "${WORK_DIR}/extract/"

echo "[3/3] 파일 복사 중..."
_copy_if_exists() {
    local src="$1" dst="$2"
    if [ -f "${src}" ]; then
        cp -v "${src}" "${dst}"
    fi
}

EX="${WORK_DIR}/extract"
# Mali 주 라이브러리 — GBM/EGL 백엔드 (KMS/DRM 환경용)
_copy_if_exists "${EX}/usr/lib/libMali.so"                                                         "${BLOBS_DIR}/libMali.so"
# CSF 펌웨어 — Mali-G310 Valhall 전용, 커널이 부팅 시 GPU에 로드
_copy_if_exists "${EX}/lib/firmware/mali_csffw.bin"                                                "${BLOBS_DIR}/lib/firmware/mali_csffw.bin"
# Vulkan WSI 레이어 (선택 사항)
_copy_if_exists "${EX}/usr/share/vulkan/implicit_layer.d/libVkLayer_window_system_integration.so"  "${BLOBS_DIR}/vulkan/"
_copy_if_exists "${EX}/usr/share/vulkan/implicit_layer.d/VkLayer_window_system_integration.json"   "${BLOBS_DIR}/vulkan/"
_copy_if_exists "${EX}/usr/share/vulkan/icd.d/mali.json"                                           "${BLOBS_DIR}/vulkan/"

if [ ! -f "${BLOBS_DIR}/libMali.so" ]; then
    echo "ERROR: libMali.so를 찾을 수 없습니다. tarball 내부 구조:"
    find "${WORK_DIR}/extract" -name "*.so" -o -name "*.bin" 2>/dev/null | head -20
    exit 1
fi

echo ""
echo "[OK] Mali blobs 설치 완료: ${BLOBS_DIR}"
