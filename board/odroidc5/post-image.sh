#!/bin/bash
# post-image.sh - SD 카드 이미지 생성

set -e

BOARD_DIR="$(dirname "$0")"
BINARIES_DIR="${BINARIES_DIR:-output/images}"

echo ">>> RETROPANGUI-C5 post-image script 실행"

# u-boot를 images 디렉토리로 복사
cp "${BOARD_DIR}/u-boot.bin.sd.bin" "${BINARIES_DIR}/"

# config.ini 복사 — U-Boot 바이너리(board_late_init())가 boot.cmd 실행 전에
# 자동으로 파티션1 루트에서 읽어서 "ini generic $loadaddr"로 파싱함(2026-07-12
# U-Boot 소스 확인 완료). displaymode="720p60hz"를 안전한 범용 부팅 기본값으로
# 지정 - 이후 S60display가 EDID 확인해서 모니터별 최적 해상도로 재적용함.
# 섹션명은 반드시 [generic] - 위키 예제의 "target"은 실제 섹션명이 아니라
# 코드블록 위젯 탭 이름이었음(오독 확인됨).
cp "${BOARD_DIR}/config.ini" "${BINARIES_DIR}/"

# boot.scr 생성 (boot.cmd 소스에서 mkimage로 컴파일)
MKIMAGE=$(find "${HOST_DIR}" -name mkimage -type f 2>/dev/null | head -1)
if [ -z "${MKIMAGE}" ]; then
    MKIMAGE=$(find "${BOARD_DIR}/../../output/build" -name mkimage -path "*/tools/mkimage" 2>/dev/null | head -1)
fi
${MKIMAGE} -A arm64 -O linux -T script -C none -n "RETROPANGUI-C5 Boot Script" \
    -d "${BOARD_DIR}/boot.cmd" "${BINARIES_DIR}/boot.scr"

# squashfs → retropangui.squashfs (genimage.cfg가 이 이름으로 참조)
cp "${BINARIES_DIR}/rootfs.squashfs" "${BINARIES_DIR}/retropangui.squashfs"

# overlay 파티션 이미지 생성 (ext4, 3GB) — genimage가 ext4 타입을 미지원할 수 있으므로 직접 생성
# 2026-07-06: 1GB → 3GB로 확장 — AI CLI(Claude Code/Gemini CLI/Codex CLI, 실측
# 약 573MB 합계)를 $HOME(=/, overlay)에 npm install -g로 설치해두는 용도로 확정.
if [ ! -f "${BINARIES_DIR}/overlay.ext4" ]; then
    echo ">>> overlay.ext4 생성 중 (3GB)..."
    dd if=/dev/zero of="${BINARIES_DIR}/overlay.ext4" bs=1M count=3072 status=progress
    mkfs.ext4 -L overlay -F "${BINARIES_DIR}/overlay.ext4"
fi

# genimage를 사용하여 SD 카드 이미지 조립
rm -rf "${BINARIES_DIR}/genimage.tmp"
genimage \
    --rootpath "${TARGET_DIR}" \
    --tmppath "${BINARIES_DIR}/genimage.tmp" \
    --inputpath "${BINARIES_DIR}" \
    --outputpath "${BINARIES_DIR}" \
    --config "${BOARD_DIR}/genimage.cfg"

echo ">>> SD 카드 이미지 생성 완료: ${BINARIES_DIR}/sdcard.img"
