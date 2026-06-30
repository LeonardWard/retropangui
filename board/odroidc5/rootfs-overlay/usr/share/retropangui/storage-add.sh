#!/bin/sh
# 외부 저장장치 감지 helper (udev RUN에서 호출)
# 부트 디바이스를 /proc/mounts에서 동적으로 판단하여 제외

DEV="$1"

# 파티션인지 확인
[ -f "/sys/class/block/${DEV}/partition" ] || exit 0

# 부트 디바이스 결정 (/boot 마운트포인트 기준, 없으면 / 기준)
BOOT_PART=$(awk '$2=="/boot"{print $1; exit}' /proc/mounts | sed 's|/dev/||')
[ -z "${BOOT_PART}" ] && \
    BOOT_PART=$(awk '$2=="/" && $1!="rootfs" && $1!="overlay" {print $1; exit}' /proc/mounts | sed 's|/dev/||')

if [ -z "${BOOT_PART}" ]; then
    # 판단 불가 시 mmcblk0 기본값으로 fallback
    BOOT_DEV="mmcblk0"
else
    # mmcblk0p1 → mmcblk0, sda1 → sda
    BOOT_DEV=$(echo "${BOOT_PART}" | sed 's/p\?[0-9]*$//')
fi

# 부트 디바이스의 파티션이면 건너뜀
case "${DEV}" in
    ${BOOT_DEV}*) exit 0 ;;
esac

echo "${DEV}" >> /tmp/retropangui-new-storage
