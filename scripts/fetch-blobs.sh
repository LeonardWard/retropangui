#!/bin/bash
# fetch-blobs.sh - Mali DDK 전용 바이너리 다운로드 스크립트
#
# ARM Mali-G310 Valhall DDK r44p0는 ARM 전용 라이선스로 인해
# 공개 저장소에 포함할 수 없습니다.
# 이 스크립트는 Hardkernel 공식 Ubuntu 24.04 이미지에서 추출합니다.
#
# 사용법:
#   bash scripts/fetch-blobs.sh
#
# 또는 수동으로 설치하려면 board/odroidc5/blobs/README.md 참고

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BLOBS_DIR="${SCRIPT_DIR}/../board/odroidc5/blobs/mali"
WORK_DIR="$(mktemp -d)"

echo "========================================"
echo "  C5-PANGUI Mali DDK 블롭 다운로드"
echo "========================================"

# 이미 있으면 스킵
if [ -f "${BLOBS_DIR}/libMali.so" ]; then
    echo "[OK] Mali blobs already present: ${BLOBS_DIR}/libMali.so"
    echo "     강제 재다운로드: rm -rf ${BLOBS_DIR} && bash scripts/fetch-blobs.sh"
    exit 0
fi

mkdir -p "${BLOBS_DIR}/lib/firmware" "${BLOBS_DIR}/vulkan"

# ────────────────────────────────────────────────────────────
# 방법 1: Hardkernel apt 저장소에서 deb 패키지 직접 다운로드
# ────────────────────────────────────────────────────────────
HARDKERNEL_APT="https://dn.odroid.com/ubuntu/ubuntu24"

echo "[1/3] Hardkernel apt 저장소에서 Mali 패키지 검색 중..."

# apt Packages 목록에서 Mali 패키지 경로 자동 탐색
PACKAGES_URL="${HARDKERNEL_APT}/dists/noble/main/binary-arm64/Packages.gz"
MALI_DEB_PATH=""

if curl -fsSL --connect-timeout 15 "${PACKAGES_URL}" \
    | gunzip \
    | grep -A 2 "^Package:.*mali" \
    | grep "^Filename:" \
    | grep -i "valhall\|g310\|mali" \
    | head -1 \
    | read -r _ MALI_DEB_PATH; then
    true
fi

if [ -n "${MALI_DEB_PATH}" ]; then
    DEB_URL="${HARDKERNEL_APT}/${MALI_DEB_PATH}"
    echo "  발견: ${MALI_DEB_PATH}"
    echo "[2/3] 다운로드 중: ${DEB_URL}"
    curl -fL --progress-bar -o "${WORK_DIR}/mali.deb" "${DEB_URL}"

    echo "[3/3] 추출 중..."
    dpkg -x "${WORK_DIR}/mali.deb" "${WORK_DIR}/mali_extracted/"

    # 파일 복사
    _copy_if_exists() {
        local src="$1" dst="$2"
        if [ -f "${src}" ]; then
            cp -v "${src}" "${dst}"
        fi
    }

    _copy_if_exists "${WORK_DIR}/mali_extracted/usr/lib/libMali.so"               "${BLOBS_DIR}/libMali.so"
    _copy_if_exists "${WORK_DIR}/mali_extracted/lib/firmware/mali_csffw.bin"       "${BLOBS_DIR}/lib/firmware/mali_csffw.bin"
    _copy_if_exists "${WORK_DIR}/mali_extracted/usr/share/vulkan/implicit_layer.d/libVkLayer_window_system_integration.so" \
                                                                                    "${BLOBS_DIR}/vulkan/"
    _copy_if_exists "${WORK_DIR}/mali_extracted/usr/share/vulkan/implicit_layer.d/VkLayer_window_system_integration.json" \
                                                                                    "${BLOBS_DIR}/vulkan/"
    _copy_if_exists "${WORK_DIR}/mali_extracted/usr/share/vulkan/icd.d/mali.json"  "${BLOBS_DIR}/vulkan/"

    rm -rf "${WORK_DIR}"
    echo ""
    echo "[OK] Mali blobs 설치 완료: ${BLOBS_DIR}"
    exit 0
fi

# ────────────────────────────────────────────────────────────
# 방법 2: 수동 추출 안내
# ────────────────────────────────────────────────────────────
rm -rf "${WORK_DIR}"
echo ""
echo "========================================"
echo "  자동 다운로드 실패 — 수동 추출 필요"
echo "========================================"
echo ""
echo "1. Hardkernel 공식 Odroid C5 Ubuntu 24.04 이미지 다운로드:"
echo "   https://odroid.in/ubuntu_24.04lts/"
echo "   (파일: ubuntu-24.04-server-odroidc5-*.img.xz)"
echo ""
echo "2. 이미지에서 rootfs 파티션 마운트 후 아래 파일들 복사:"
echo ""
echo "   소스 경로                                       → 복사 대상"
echo "   /usr/lib/libMali.so                             → board/odroidc5/blobs/mali/libMali.so"
echo "   /lib/firmware/mali_csffw.bin                    → board/odroidc5/blobs/mali/lib/firmware/mali_csffw.bin"
echo "   /usr/share/vulkan/implicit_layer.d/libVkLayer*  → board/odroidc5/blobs/mali/vulkan/"
echo "   /usr/share/vulkan/implicit_layer.d/VkLayer*.json→ board/odroidc5/blobs/mali/vulkan/"
echo "   /usr/share/vulkan/icd.d/mali.json               → board/odroidc5/blobs/mali/vulkan/"
echo ""
echo "3. 다시 빌드: ./build.sh"
echo ""
exit 1
