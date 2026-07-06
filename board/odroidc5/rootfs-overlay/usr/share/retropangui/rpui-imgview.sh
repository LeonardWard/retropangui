#!/bin/sh
# 스크린샷 뷰어 - "screenshots" 가상 시스템에서 이미지를 선택했을 때 실행됨
# (systems.json의 screenshots 항목 "command"로 지정, 2026-07-06).
#
# cores가 없는 시스템은 기본적으로 %ROM%을 그대로 실행하는데(utility의 .sh
# 처럼), PNG/JPG는 실행 파일이 아니라 그냥 실행하면 아무 일도 안 일어남 -
# 골라도 "볼 수가 없다"는 피드백으로 발견. mpv(이미 스플래시 재생에 씀)로
# DRM에 직접 띄우고, 정지 이미지라 기본으로는 바로 끝나버리므로
# --loop-file=inf로 계속 띄워둠.
IMG="$1"
[ -f "${IMG}" ] || exit 1

mpv --loop-file=inf --vo=drm --drm-device=/dev/dri/card0 \
    --no-audio --really-quiet \
    "${IMG}" &
MPV_PID=$!

# 패드 "b"(뒤로가기)로 종료 - 버튼 evdev 코드는 패드마다 달라서
# es_input.cfg에서 그대로 읽어서 쓴다(rpui-termkeys.py와 동일 방식).
python3 /usr/share/retropangui/rpui-imgviewkeys.py "${MPV_PID}" &
WATCHER_PID=$!

wait "${MPV_PID}" 2>/dev/null
kill "${WATCHER_PID}" 2>/dev/null
