#!/bin/bash
# flash-sd.sh - RetroPangui SD카드 플래싱 스크립트
#
# 사용법:
#   bash scripts/flash-sd.sh                  # 최신 이미지 자동 선택
#   bash scripts/flash-sd.sh output/foo.img   # 이미지 직접 지정

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${PROJECT_DIR}/output"

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
BLU='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLU}================================================${NC}"
echo -e "${BLU}  RetroPangui SD카드 플래싱 도구${NC}"
echo -e "${BLU}================================================${NC}"
echo ""

# ── 이미지 선택 ──────────────────────────────────────────
if [ -n "$1" ]; then
    IMAGE="$1"
else
    IMAGE="$(ls -t "${OUTPUT_DIR}"/retropangui-*.img 2>/dev/null | head -1)"
fi

if [ -z "${IMAGE}" ] || [ ! -f "${IMAGE}" ]; then
    echo -e "${RED}[ERROR] 이미지 파일을 찾을 수 없습니다.${NC}"
    echo "  ./build.sh 로 먼저 빌드하거나 이미지 경로를 직접 지정하세요."
    echo "  사용법: bash scripts/flash-sd.sh [이미지경로]"
    exit 1
fi

IMAGE_SIZE="$(du -h "${IMAGE}" | cut -f1)"
echo -e "  이미지: ${GRN}$(basename "${IMAGE}")${NC} (${IMAGE_SIZE})"
echo ""

# ── SD카드 자동 탐색 ──────────────────────────────────────
find_sd_cards() {
    local candidates=()
    for dev in /sys/block/sd* /sys/block/mmcblk*; do
        [ -e "$dev" ] || continue
        local name="$(basename "$dev")"
        local devpath="/dev/${name}"

        # 존재하지 않는 장치 스킵
        [ -b "$devpath" ] || continue

        # 루트 파티션이 이 디스크에 있으면 스킵 (시스템 디스크 보호)
        if lsblk -no MOUNTPOINT "${devpath}" 2>/dev/null | grep -q "^/$"; then
            continue
        fi

        # 크기 확인 (1GB ~ 512GB 범위만)
        local size_bytes="$(cat "${dev}/size" 2>/dev/null || echo 0)"
        local size_gb=$(( size_bytes * 512 / 1024 / 1024 / 1024 ))
        if [ "$size_gb" -lt 1 ] || [ "$size_gb" -gt 512 ]; then
            continue
        fi

        # removable 또는 mmcblk 장치 우선
        local removable="$(cat "${dev}/removable" 2>/dev/null || echo 0)"
        if [ "$removable" = "1" ] || echo "$name" | grep -q "^mmcblk"; then
            candidates+=("${devpath}")
        fi
    done
    echo "${candidates[@]}"
}

echo "SD카드를 탐색 중..."
read -ra CANDIDATES <<< "$(find_sd_cards)"

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
    echo -e "${RED}[ERROR] SD카드를 찾을 수 없습니다.${NC}"
    echo ""
    echo "  SD카드가 꽂혀 있는지 확인하거나, 장치를 직접 입력하세요:"
    echo -n "  장치 경로 (예: /dev/sdb, /dev/mmcblk0): "
    read -r DEVICE
    [ -b "${DEVICE}" ] || { echo -e "${RED}유효하지 않은 장치입니다.${NC}"; exit 1; }
elif [ "${#CANDIDATES[@]}" -eq 1 ]; then
    DEVICE="${CANDIDATES[0]}"
else
    echo ""
    echo "SD카드 후보가 여러 개 발견됐습니다:"
    for i in "${!CANDIDATES[@]}"; do
        dev="${CANDIDATES[$i]}"
        model="$(cat /sys/block/$(basename "$dev")/device/model 2>/dev/null | tr -d ' ' || echo "unknown")"
        size="$(lsblk -dno SIZE "$dev" 2>/dev/null || echo "?")"
        echo "  $((i+1))) ${dev}  ${size}  ${model}"
    done
    echo ""
    echo -n "  선택 (번호 입력): "
    read -r CHOICE
    DEVICE="${CANDIDATES[$((CHOICE-1))]}"
    [ -b "${DEVICE}" ] || { echo -e "${RED}잘못된 선택입니다.${NC}"; exit 1; }
fi

# ── 장치 정보 출력 ────────────────────────────────────────
DEV_NAME="$(basename "${DEVICE}")"
DEV_SIZE="$(lsblk -dno SIZE "${DEVICE}" 2>/dev/null || echo "?")"
DEV_MODEL="$(cat /sys/block/${DEV_NAME}/device/model 2>/dev/null | xargs || echo "unknown")"
DEV_TRAN="$(lsblk -dno TRAN "${DEVICE}" 2>/dev/null || echo "?")"

echo ""
echo -e "  장치: ${GRN}${DEVICE}${NC}"
echo -e "  크기: ${DEV_SIZE}"
echo -e "  모델: ${DEV_MODEL}"
echo -e "  연결: ${DEV_TRAN}"
echo ""

# ── 마운트된 파티션 해제 ──────────────────────────────────
MOUNTED="$(lsblk -no MOUNTPOINT "${DEVICE}" 2>/dev/null | grep -v '^$' || true)"
if [ -n "${MOUNTED}" ]; then
    echo -e "${YLW}마운트된 파티션을 해제합니다...${NC}"
    for part in "${DEVICE}"[0-9]* "${DEVICE}"p[0-9]*; do
        [ -b "$part" ] && sudo umount "$part" 2>/dev/null || true
    done
    sudo umount "${DEVICE}" 2>/dev/null || true
fi

# ── 최종 확인 ─────────────────────────────────────────────
echo -e "${RED}경고: ${DEVICE} 의 모든 데이터가 삭제됩니다!${NC}"
echo ""
echo -n "  계속하려면 'yes' 입력: "
read -r CONFIRM
if [ "${CONFIRM}" != "yes" ]; then
    echo "취소됐습니다."
    exit 0
fi

echo ""

# ── 앞부분 초기화 (파티션 테이블 + 부트로더 영역) ────────
echo -e "${YLW}[1/2] SD카드 초기화 (앞 32MB)...${NC}"
sudo dd if=/dev/zero of="${DEVICE}" bs=1M count=32 status=progress
sync

# ── 이미지 플래싱 ─────────────────────────────────────────
echo ""
echo -e "${YLW}[2/2] 이미지 플래싱 중...${NC}"
sudo dd if="${IMAGE}" of="${DEVICE}" bs=4M status=progress conv=fsync
sync

echo ""
echo -e "${GRN}================================================${NC}"
echo -e "${GRN}  플래싱 완료!${NC}"
echo -e "${GRN}  이미지: $(basename "${IMAGE}")${NC}"
echo -e "${GRN}  장치:   ${DEVICE}${NC}"
echo -e "${GRN}================================================${NC}"
echo ""
echo "SD카드를 안전하게 제거한 후 Odroid C5에 꽂으세요."
echo ""
