#!/bin/sh
# update-theme-screenshot.sh - ES game-end 훅. 게임 종료 시마다 방금 플레이한
# 시스템의 최신 스크린샷을 retropangui-slate 테마의 우측상단 시스템 에셋으로 갱신.
#
# ES(retropangui-emulationstation commit 7440652 이후)가 game-end 이벤트에
# 인자 2개를 넘김: $1=system.getName()(스크린샷 폴더명, 예: msx1),
# $2=system.getThemeFolder()(테마 파일명, 예: msx) - 두 값이 다른 시스템이
# 있어서(msx1->msx, dos->pc, utility->ports) 반드시 구분해서 써야 함.
#
# 목표 문서: docs/retropangui/todo-20260613-screenshot-system.html

SYSTEM_NAME="$1"
THEME_NAME="$2"
SHARE_ROOT="${RETROPANGUI_SHARE:-/retropangui/share}"
THEME_DIR="${SHARE_ROOT}/system/emulationstation/themes/retropangui-slate"

[ -z "${SYSTEM_NAME}" ] && exit 0
[ -z "${THEME_NAME}" ] && exit 0

SCREENSHOT_DIR="${SHARE_ROOT}/screenshots/${SYSTEM_NAME}"
[ -d "${SCREENSHOT_DIR}" ] || exit 0

# 가장 최근 스크린샷(mtime 기준) 하나. find -printf/-newer는 busybox find에
# 없어서(findutils 미포함 - 위 configs 확인) 대신 busybox에 항상 있는
# `ls -t`로 최신 항목을 뽑음. RetroArch 스크린샷은 항상 .png.
LATEST=$(ls -t "${SCREENSHOT_DIR}"/*.png 2>/dev/null | head -n 1)
[ -z "${LATEST}" ] && exit 0

TARGET_DIR="${THEME_DIR}/_assets/screenshots"
TARGET="${TARGET_DIR}/${THEME_NAME}.png"

mkdir -p "${TARGET_DIR}"
cp -f "${LATEST}" "${TARGET}" 2>/dev/null || true

exit 0
