#!/bin/sh
# ota-update.sh - OTA squashfs 다운로드, 검증, /boot/update/ 스테이징
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

echo ">>> /boot/update/ 스테이징 중..."
if ! mount -o remount,rw /boot 2>/dev/null; then
    echo "ERROR: /boot remount rw 실패"
    exit 1
fi
mkdir -p /boot/update
mv "${TMP_DIR}/update.squashfs" /boot/update/retropangui.update
cp "${TMP_DIR}/update.sha256"   /boot/update/retropangui.update.sha256
mount -o remount,ro /boot 2>/dev/null || true
sync

echo ">>> 업데이트 스테이징 완료 — 재부팅 시 적용됩니다"
exit 0
