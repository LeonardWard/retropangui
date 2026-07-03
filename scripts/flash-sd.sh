#!/bin/bash
# flash-sd.sh - RetroPangui SD카드 플래싱 스크립트
#
# 사용법:
#   bash scripts/flash-sd.sh            # 최신 이미지, share 초기화 (기본)
#   bash scripts/flash-sd.sh -k         # 최신 이미지, 기존 share 보존
#   bash scripts/flash-sd.sh foo.img    # 이미지 지정, share 초기화
#   bash scripts/flash-sd.sh -k foo.img # 이미지 지정 + share 보존
#
# 기본 동작 (전체 초기화):
#   카드 전체를 0으로 비운 뒤 이미지를 쓴다.
#   첫 부팅 시 S61share가 마운트 실패 → mkfs.exfat으로 새 share 파티션 생성.
#
# -k:
#   이미지만 쓰고 나머지를 건드리지 않는다. 기존 ROM/세이브 데이터가 보존된다.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${PROJECT_DIR}/output"

# ── 옵션 파싱 ─────────────────────────────────────────────
PRESERVE_SHARE=false
POSITIONAL=""
for arg in "$@"; do
    case "$arg" in
        -k) PRESERVE_SHARE=true ;;
        *) POSITIONAL="$arg" ;;
    esac
done
set -- ${POSITIONAL}

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
BLU='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLU}================================================${NC}"
echo -e "${BLU}  RetroPangui SD카드 플래싱 도구${NC}"
if [ "${PRESERVE_SHARE}" = "true" ]; then
echo -e "${BLU}  모드: share 파티션 보존${NC}"
else
echo -e "${BLU}  모드: 전체 초기화 (share 새로 생성)${NC}"
fi
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

# ── 기존 파티션 확인 ──────────────────────────────────────
# share 파티션처럼 이미지에 없던 예전 데이터가 카드에 남아있으면
# 재플래싱해도 안 지워지는 문제가 있어서, 파티션이 여러 개면 전부 삭제한다.
EXISTING_PARTS=()
for part in "${DEVICE}"[0-9]* "${DEVICE}"p[0-9]*; do
    [ -b "$part" ] && EXISTING_PARTS+=("$part")
done

if [ "${#EXISTING_PARTS[@]}" -gt 1 ]; then
    echo -e "${YLW}기존 파티션 ${#EXISTING_PARTS[@]}개 발견:${NC}"
    for p in "${EXISTING_PARTS[@]}"; do
        sz="$(lsblk -dno SIZE "$p" 2>/dev/null || echo "?")"
        fs="$(lsblk -dno FSTYPE "$p" 2>/dev/null || echo "?")"
        echo "    ${p}  ${sz}  ${fs}"
    done
fi

delete_all_partitions() {
    local dev="$1"
    local parts=()
    for part in "${dev}"[0-9]* "${dev}"p[0-9]*; do
        [ -b "$part" ] && parts+=("$part")
    done

    if [ "${#parts[@]}" -eq 0 ]; then
        return
    fi

    echo -e "${YLW}파티션 ${#parts[@]}개 삭제 중...${NC}"
    for p in "${parts[@]}"; do
        sudo umount "$p" 2>/dev/null || true
        sudo wipefs -a "$p" 2>/dev/null || true
    done

    # 파티션 테이블 자체를 비움 (MBR/GPT 무관하게 동작)
    sudo sfdisk --delete "${dev}" 2>/dev/null || true
    sudo wipefs -a "${dev}" 2>/dev/null || true
    sync
}

# ── 최종 확인 ─────────────────────────────────────────────
if [ "${PRESERVE_SHARE}" = "true" ]; then
    echo -e "${RED}경고: ${DEVICE} 의 boot/overlay 파티션이 덮어써집니다. share는 보존됩니다.${NC}"
else
    echo -e "${RED}경고: ${DEVICE} 의 모든 데이터가 삭제됩니다! (share 포함)${NC}"
fi
echo ""
echo -n "  계속하려면 'yes' 또는 'y' 입력: "
read -r CONFIRM
if [ "${CONFIRM}" != "yes" ] && [ "${CONFIRM}" != "y" ]; then
    echo "취소됐습니다."
    exit 0
fi

echo ""

# ── 이미지 플래싱 ─────────────────────────────────────────
if [ "${PRESERVE_SHARE}" = "true" ]; then
    echo -e "${YLW}[1/1] 이미지 플래싱 중 (기존 데이터 보존)...${NC}"
    sudo dd if="${IMAGE}" of="${DEVICE}" bs=4M status=progress conv=fsync
    sync
else
    echo -e "${YLW}[1/2] 파티션 테이블 초기화 중...${NC}"
    if [ "${#EXISTING_PARTS[@]}" -gt 1 ]; then
        delete_all_partitions "${DEVICE}"
    fi
    sudo wipefs -a "${DEVICE}"
    sudo dd if=/dev/zero of="${DEVICE}" bs=4M count=8 status=progress
    sync

    echo ""
    echo -e "${YLW}[2/2] 이미지 플래싱 중...${NC}"
    sudo dd if="${IMAGE}" of="${DEVICE}" bs=4M status=progress conv=fsync
    sync
fi

echo ""
echo -e "${GRN}================================================${NC}"
echo -e "${GRN}  플래싱 완료!${NC}"
echo -e "${GRN}  이미지: $(basename "${IMAGE}")${NC}"
echo -e "${GRN}  장치:   ${DEVICE}${NC}"
echo -e "${GRN}================================================${NC}"
echo ""
echo "SD카드를 안전하게 제거한 후 Odroid C5에 꽂으세요."
echo ""

# ── 완료 알림음 (비프 3회) ────────────────────────────────
# PC 스피커(메인보드 부저) 우선 — 사운드카드에 스피커가 안 물려 있어도 들림
# (pcspkr 모듈의 input 장치에 EV_SND/SND_TONE 이벤트를 직접 씀)
PCSPKR="$(grep -l '^PC Speaker$' /sys/class/input/event*/device/name 2>/dev/null | head -1)"
if [ -n "${PCSPKR}" ]; then
    PCSPKR="/dev/input/$(basename "$(dirname "$(dirname "${PCSPKR}")")")"
    tone() {
        printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x12\x00\x02\x00'"$1" \
            | sudo tee "${PCSPKR}" >/dev/null 2>&1 || true
    }
    # 도미솔도 상행 멜로디 (C5 523Hz, E5 659Hz, G5 784Hz, C6 1047Hz)
    for note in '\x0b\x02\x00\x00' '\x93\x02\x00\x00' '\x10\x03\x00\x00' '\x17\x04\x00\x00'; do
        tone "$note"
        sleep 0.2
        tone '\x00\x00\x00\x00'   # 끄기
        sleep 0.05
    done
elif command -v aplay >/dev/null 2>&1; then
    for _ in 1 2 3; do
        awk 'BEGIN{for(i=0;i<4000;i++)printf "%c",128+100*sin(i*0.55)}' \
            | aplay -q -r 8000 -f U8 -t raw - 2>/dev/null || true
        sleep 0.15
    done
else
    for _ in 1 2 3; do printf '\a'; sleep 0.3; done
fi
