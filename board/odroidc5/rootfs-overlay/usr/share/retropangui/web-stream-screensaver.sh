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
# 아무 입력(키보드/패드)이나 들어오면 즉시 종료 - wait-for-input.py가
# 진짜 키 눌림(EV_KEY, value=1)만 골라서 감지함. 처음엔 dd로 32바이트만
# 읽는 방식이었는데, 장치를 열자마자 커널이 보내는 초기 상태 리포트에
# 바로 반응해버려서 mpv가 뜨자마자 즉시 종료되는 버그가 있었음
# (2026-07-23 실기기 확인 - screensaver-start와 재init 로그가 같은 초에 찍힘).

URL="$1"
if [ -z "$URL" ]; then
    echo "usage: $0 <stream-url>" >&2
    exit 1
fi

mpv --vo=drm --drm-device=/dev/dri/card0 --loop=inf --no-input-terminal \
    --no-osc --really-quiet "$URL" &
MPV_PID=$!

# mpv가 DRM 모드셋을 완전히 끝내기 전에 죽이면(입력 오탐 등) DRM이 불완전한
# 상태로 남아 ES가 재init해도 화면이 안 살아나는 문제가 있었음(2026-07-23
# 실기기 확인 - 화면이 커널 콘솔에 완전히 멈춤). 최소 2초는 무조건 기다린
# 뒤에야 입력 감지를 시작해서 이 경합을 원천 차단.
sleep 2

python3 /usr/share/retropangui/wait-for-input.py &
WAITER_PID=$!

# 둘 중 하나라도 죽으면 리턴 - mpv가 스트림 문제 등으로 먼저 죽어도
# 입력 대기만 하다가 무한정 멈춰있지 않게 함
while kill -0 "$MPV_PID" 2>/dev/null && kill -0 "$WAITER_PID" 2>/dev/null; do
    sleep 0.3
done

kill "$MPV_PID" "$WAITER_PID" 2>/dev/null
wait 2>/dev/null
# mpv가 DRM master를 완전히 내려놓을 시간을 조금 더 줌(ES window->init()이
# 곧바로 이어서 DRM을 다시 잡으려 할 때 경합 방지)
sleep 0.5
exit 0
