#!/bin/sh
# ota-update.sh - OTA squashfs+initramfs 다운로드, 검증, /boot/update/ 스테이징
# 사용법: ota-update.sh <server_url> [device]
# 종료값: 0=성공, 1=실패

SERVER_URL="$1"
DEVICE="${2:-odroidc5}"

if [ -z "${SERVER_URL}" ]; then
    echo "ERROR: server_url 인자 필요"
    exit 1
fi

SQUASHFS_URL="${SERVER_URL}/retropangui-${DEVICE}.squashfs"
SHA256_URL="${SERVER_URL}/retropangui-${DEVICE}.squashfs.sha256"
INITRAMFS_URL="${SERVER_URL}/retropangui-${DEVICE}.initramfs.cpio.gz"
INITRAMFS_SHA256_URL="${SERVER_URL}/retropangui-${DEVICE}.initramfs.cpio.gz.sha256"
TMP_DIR="/tmp/ota-$$"

cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

mkdir -p "${TMP_DIR}"

echo ">>> squashfs 다운로드 중: ${SQUASHFS_URL}"
if ! wget -qO "${TMP_DIR}/update.squashfs" "${SQUASHFS_URL}"; then
    echo "ERROR: squashfs 다운로드 실패"
    exit 1
fi

echo ">>> SHA256 다운로드 중..."
if ! wget -qO "${TMP_DIR}/update.sha256" "${SHA256_URL}"; then
    echo "ERROR: SHA256 다운로드 실패"
    exit 1
fi

echo ">>> SHA256 검증 중..."
EXPECTED=$(awk '{print $1}' "${TMP_DIR}/update.sha256")
ACTUAL=$(sha256sum "${TMP_DIR}/update.squashfs" | awk '{print $1}')
if [ "${EXPECTED}" != "${ACTUAL}" ]; then
    echo "ERROR: SHA256 불일치 (예상: ${EXPECTED}, 실제: ${ACTUAL})"
    exit 1
fi
echo ">>> SHA256 검증 완료"

# initramfs: 서버에 있으면 함께 다운로드 (없어도 실패 아님)
if wget -qO "${TMP_DIR}/update.initramfs.cpio.gz" "${INITRAMFS_URL}" 2>/dev/null; then
    echo ">>> initramfs SHA256 검증 중..."
    if wget -qO "${TMP_DIR}/update.initramfs.sha256" "${INITRAMFS_SHA256_URL}" 2>/dev/null; then
        EXPECTED_I=$(awk '{print $1}' "${TMP_DIR}/update.initramfs.sha256")
        ACTUAL_I=$(sha256sum "${TMP_DIR}/update.initramfs.cpio.gz" | awk '{print $1}')
        if [ "${EXPECTED_I}" != "${ACTUAL_I}" ]; then
            echo "ERROR: initramfs SHA256 불일치"
            exit 1
        fi
        echo ">>> initramfs SHA256 검증 완료"
    fi
else
    echo ">>> initramfs: 서버에 없음 (squashfs만 업데이트)"
    rm -f "${TMP_DIR}/update.initramfs.cpio.gz"
fi

echo ">>> /boot/update/ 스테이징 중..."
if ! mount -o remount,rw /boot 2>/dev/null; then
    echo "ERROR: /boot remount rw 실패"
    exit 1
fi
mkdir -p /boot/update
mv "${TMP_DIR}/update.squashfs" /boot/update/retropangui.update
cp "${TMP_DIR}/update.sha256"   /boot/update/retropangui.update.sha256
if [ -f "${TMP_DIR}/update.initramfs.cpio.gz" ]; then
    mv "${TMP_DIR}/update.initramfs.cpio.gz" /boot/update/initramfs.update.cpio.gz
fi
mount -o remount,ro /boot 2>/dev/null || true
sync

echo ">>> 업데이트 스테이징 완료 — 재부팅 시 적용됩니다"
exit 0
