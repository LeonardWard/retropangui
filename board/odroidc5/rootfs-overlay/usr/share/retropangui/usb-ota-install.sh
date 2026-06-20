#!/bin/bash
# USB 업데이트 설치: squashfs 파일을 /boot/update/retropangui.update 로 복사
# Usage: usb-ota-install.sh <squashfs_path>
# Returns: 0 on success, 1 on failure

set -e

SRC="$1"
DEST="/boot/update/retropangui.update"
SHA_SRC="${SRC%.squashfs}.sha256"

if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
	echo "ERROR: source file not found: $SRC" >&2
	exit 1
fi

if [ -f "$SHA_SRC" ]; then
	EXPECTED=$(awk '{print $1}' "$SHA_SRC")
	ACTUAL=$(sha256sum "$SRC" | awk '{print $1}')
	if [ "$EXPECTED" != "$ACTUAL" ]; then
		echo "ERROR: SHA256 mismatch" >&2
		exit 1
	fi
fi

mkdir -p "$(dirname "$DEST")"
mount -o remount,rw /boot 2>/dev/null || true

cp "$SRC" "$DEST"
sync

echo "OK: copied $SRC -> $DEST"
exit 0
