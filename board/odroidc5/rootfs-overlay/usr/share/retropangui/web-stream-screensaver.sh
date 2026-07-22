#!/bin/sh
# RetroPangui: 웹 스트림 스크린세이버 - mpv를 외부 프로세스로 DRM에 직접 재생.
#
# ES 내장 VLC 콜백 기반 소프트웨어 디코딩(VideoVlcComponent)이 라이브
# 네트워크 스트림에서 디코딩 깨짐(2026-07-23 실기기 확인 - 화면 일부만
# 나오고 나머지는 회색)을 일으켜서, 이미 검증된 스플래시 영상 재생 방식
# (mpv --vo=drm, S99emulationstation에서 이미 씀)을 그대로 재사용.
# ES가 launchGame()에서 게임을 외부 프로세스로 실행할 때와 동일한 패턴 -
# 이 스크립트를 부르기 전에 ES가 window/input/audio를 deinit해서 DRM
# master를 완전히 내줘야 함(SystemScreenSaver.cpp 참고).
#
# 아무 입력(키보드/패드)이나 들어오면 즉시 종료 - /dev/input/eventN을
# 전부 병렬로 읽어서(각 이벤트 구조체 크기만큼) 하나라도 이벤트가 오면
# 리턴되는 걸로 감지. Busybox ash에는 bash의 "wait -n"이 없어서 대신
# 센티넬 파일 폴링 방식 사용.

URL="$1"
if [ -z "$URL" ]; then
    echo "usage: $0 <stream-url>" >&2
    exit 1
fi

SENTINEL="/tmp/.web-stream-input-detected"
rm -f "$SENTINEL"

mpv --vo=drm --drm-device=/dev/dri/card0 --loop=inf --no-input-terminal \
    --no-osc --really-quiet "$URL" &
MPV_PID=$!

for dev in /dev/input/event*; do
    [ -c "$dev" ] || continue
    ( dd if="$dev" of=/dev/null bs=32 count=1 2>/dev/null; touch "$SENTINEL" ) &
done

while [ ! -f "$SENTINEL" ] && kill -0 "$MPV_PID" 2>/dev/null; do
    sleep 0.2
done

kill "$MPV_PID" 2>/dev/null
# 아직 이벤트 안 들어온 나머지 dd들도 정리 (device open 상태로 남지 않게)
pkill -f "dd if=/dev/input/event" 2>/dev/null
rm -f "$SENTINEL"

wait 2>/dev/null
exit 0
