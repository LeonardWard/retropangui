#!/bin/bash
# post-image.sh - SD 카드 이미지 생성

set -e

BOARD_DIR="$(dirname "$0")"
BINARIES_DIR="${BINARIES_DIR:-output/images}"

echo ">>> RETROPANGUI-C5 post-image script 실행"

# u-boot, boot.ini를 images 디렉토리로 복사 (extlinux.conf 제거: boot.scr가 SD/eMMC 모두 처리)
cp "${BOARD_DIR}/u-boot.bin.sd.bin" "${BINARIES_DIR}/"
cp "${BOARD_DIR}/boot.ini" "${BINARIES_DIR}/"

# boot.scr 생성 (boot.cmd 소스에서 mkimage로 컴파일)
MKIMAGE=$(find "${HOST_DIR}" -name mkimage -type f 2>/dev/null | head -1)
if [ -z "${MKIMAGE}" ]; then
    MKIMAGE=$(find "${BOARD_DIR}/../../output/build" -name mkimage -path "*/tools/mkimage" 2>/dev/null | head -1)
fi
${MKIMAGE} -A arm64 -O linux -T script -C none -n "RETROPANGUI-C5 Boot Script" \
    -d "${BOARD_DIR}/boot.cmd" "${BINARIES_DIR}/boot.scr"

# genimage를 사용하여 SD 카드 이미지 조립
rm -rf "${BINARIES_DIR}/genimage.tmp"
genimage \
    --rootpath "${TARGET_DIR}" \
    --tmppath "${BINARIES_DIR}/genimage.tmp" \
    --inputpath "${BINARIES_DIR}" \
    --outputpath "${BINARIES_DIR}" \
    --config "${BOARD_DIR}/genimage.cfg"

echo ">>> SD 카드 이미지 생성 완료: ${BINARIES_DIR}/sdcard.img"
