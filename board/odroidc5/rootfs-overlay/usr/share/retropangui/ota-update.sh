#!/bin/sh
# ota-update.sh - OTA squashfs+initramfs 다운로드, 검증, /boot/update/ 스테이징
# 사용법: ota-update.sh <server_url> [device]
# 종료값: 0=성공, 1=실패
#
# 메이저 버전(태그에 정확히 일치하는 릴리스) 업데이트 시, ota-reset-on-major.list에
# 적힌 파일들을 share 파티션에서 삭제 - S95retropangui의 "없으면 최초 복사"
# 로직이 다음 부팅에서 새 번들 기본값으로 다시 채워 넣게 함. es_input.cfg처럼
# "시스템 기본값이지만 share 파티션이라 OTA로 안 갱신되던" 파일들을 위한 장치
# (2026-07-10, l1/r1 버그 수정이 실기기에 반영 안 됐던 문제에서 발견).
# retropangui.conf 등 진짜 사용자 설정은 이 목록에 넣으면 안 됨 - 아래
# reset_files_on_major_update()에도 하드코딩 안전장치가 있음.

SERVER_URL="$1"
DEVICE="${2:-odroidc5}"
RESET_LIST="/usr/share/retropangui/ota-reset-on-major.list"

if [ -z "${SERVER_URL}" ]; then
    echo "ERROR: server_url 인자 필요"
    exit 1
fi

SQUASHFS_URL="${SERVER_URL}/retropangui-${DEVICE}.squashfs"
SHA256_URL="${SERVER_URL}/retropangui-${DEVICE}.squashfs.sha256"
INITRAMFS_URL="${SERVER_URL}/retropangui-${DEVICE}.initramfs.cpio.gz"
INITRAMFS_SHA256_URL="${SERVER_URL}/retropangui-${DEVICE}.initramfs.cpio.gz.sha256"
VERSION_URL="${SERVER_URL}/version"
TMP_DIR="/tmp/ota-$$"

# 버전 문자열(git describe --tags --long 형식: TAG-N-gHASH)에서 태그 이후
# 커밋 수(N)를 뽑아냄 - N이 0이면 태그에 정확히 일치하는 "메이저" 릴리스.
# 파싱 실패(형식이 다르거나 --always 폴백 등) 시 안전하게 "메이저 아님"으로 간주.
commits_since_tag() {
    echo "$1" | sed -nE 's/^.+-([0-9]+)-g[0-9a-f]+$/\1/p'
}

# 메이저 버전 업데이트일 때만 ota-reset-on-major.list의 파일들을 삭제
reset_files_on_major_update() {
    local new_version="$1"
    local new_n
    new_n=$(commits_since_tag "${new_version}")

    if [ -z "${new_n}" ] || [ "${new_n}" != "0" ]; then
        return 0
    fi

    if [ ! -f "${RESET_LIST}" ]; then
        return 0
    fi

    echo ">>> 메이저 버전 업데이트 감지 (${new_version}) - 리셋 대상 파일 확인 중..."
    while IFS= read -r path; do
        case "${path}" in
            ""|\#*) continue ;;
        esac
        # 안전장치: retropangui.conf(사용자 설정)는 목록에 있어도 절대 삭제 안 함
        case "${path}" in
            */retropangui.conf)
                echo "    건너뜀(보호된 파일): ${path}"
                continue
                ;;
        esac
        if [ -f "${path}" ]; then
            rm -f "${path}"
            echo "    삭제됨(다음 부팅에 기본값으로 재생성): ${path}"
        fi
    done < "${RESET_LIST}"
}

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

NEW_VERSION=""
if NEW_VERSION=$(wget -qO- "${VERSION_URL}" 2>/dev/null) && [ -n "${NEW_VERSION}" ]; then
    reset_files_on_major_update "${NEW_VERSION}"
else
    echo ">>> 버전 정보 확인 실패 - 메이저 버전 리셋 스킵(치명적 오류 아님)"
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
