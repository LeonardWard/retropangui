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

# 공장 초기화용 boot.conf 원본 - initramfs가 공장 초기화 때 이 파일을
# /boot/retropangui-boot.conf 위에 그대로 복사해 sharedevice=INTERNAL 기본값
# 포함 완전 초기화함(2026-07-17 사용자 지시 - sharenetwork_*만 지우던 기존
# 방식은 NAS 설정 흔적/커스텀 잔재가 남는 문제).
cp "${BOARD_DIR}/retropangui-boot.conf.init" "${BINARIES_DIR}/"

# U-Boot 부팅 로고(boot-logo.bmp.gz) 생성 — showlogo.c의 do_showlogo()가 부팅
# 시 config.ini의 displaymode(720p60hz)로 로고를 띄울 때 자동으로 찾는 파일
# (board_late_init() → load_boot_config → showlogo, 파티션1 루트에서
# "boot-logo.bmp.gz" → "boot-logo.bmp" 순으로 시도 - CONFIG_VIDEO_BMP_GZIP=y라
# gzip 압축본을 우선 찾음, 2026-07-21 용량 절감을 위해 gz만 제공). 이 U-Boot
# 빌드는 BMP만 지원(CONFIG_CMD_BMP, 24bpp만 - PNG/JPEG 지원 없음,
# CONFIG_BMP_16/32BPP도 꺼져있음). 스플래시 비디오(post-build.sh)와 같은
# 원본 PNG를 재사용해서 720p60hz(config.ini 부팅 기본값) 해상도로 변환.
SPLASH_SRC="${BOARD_DIR}/splash/splash-src.png"
BOOTLOGO_BMP="${BINARIES_DIR}/boot-logo.bmp"
BOOTLOGO_DST="${BINARIES_DIR}/boot-logo.bmp.gz"
if [ -f "${SPLASH_SRC}" ] && command -v ffmpeg >/dev/null 2>&1; then
    echo ">>> U-Boot 부팅 로고(BMP.GZ) 생성 중..."
    ffmpeg -y -i "${SPLASH_SRC}" \
        -vf "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:color=white" \
        -pix_fmt bgr24 -frames:v 1 \
        "${BOOTLOGO_BMP}" 2>/dev/null
    gzip -f -9 "${BOOTLOGO_BMP}"
    echo ">>> U-Boot 부팅 로고 완료: ${BOOTLOGO_DST} ($(du -h "${BOOTLOGO_DST}" | cut -f1))"
else
    echo ">>> WARNING: 부팅 로고 생성 스킵 (소스 이미지 또는 ffmpeg 없음)"
fi

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
