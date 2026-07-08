#!/usr/bin/env python3
"""
rpui-termkeys - 유틸리티(터미널) 세션 전용 패드 핫키 감시.

RetroArch처럼 SELECT+START로 세션 종료, SELECT+L1(pageup)으로 스크린샷을
지원하기 위한 것. 패드마다 버튼의 evdev 코드가 완전히 다르므로(예: 어떤
패드는 select가 314인데 다른 패드는 297) 하드코딩하지 않고, ES가 이미
계산해둔 es_input.cfg의 코드를 그대로 읽어서 쓴다 - 이 프로젝트 전체에서
패드 매핑에 쓰는 것과 동일한 정답 소스(2026-07-06).

terminal.py가 백그라운드로 띄우고, 인자로 부모(터미널) 프로세스의 PID를
받는다. 종료 콤보 감지 시 그 프로세스 그룹 전체에 SIGTERM을 보내 셸을
끝내고(ES가 system() 대기 중이던 게 반환되어 자연스럽게 ES로 복귀), 이
스크립트 자신도 같은 그룹이라 함께 종료됨.
"""
import os
import signal
import struct
import subprocess
import sys
import time

sys.path.insert(0, "/usr/share/retropangui")
from rpui_padutil import detect_joysticks, find_codes_for_device  # noqa: E402

SCREENSHOT_DIR = "/retropangui/share/screenshots/utility"

# struct input_event { struct timeval time; __u16 type; __u16 code; __s32 value; }
# 64비트 aarch64/linux 기준 timeval은 long(8바이트) 2개 - 총 24바이트.
EVENT_FMT = "llHHi"
EVENT_SIZE = struct.calcsize(EVENT_FMT)
EV_KEY = 1


def log(msg):
    print(f"[termkeys] {msg}", file=sys.stderr, flush=True)


def take_screenshot():
    try:
        os.makedirs(SCREENSHOT_DIR, exist_ok=True)
    except OSError as e:
        log(f"스크린샷 폴더 생성 실패: {e}")
        return
    ts = time.strftime("%y%m%d-%H%M%S")
    out = os.path.join(SCREENSHOT_DIR, f"term-{ts}.png")
    try:
        subprocess.Popen(
            ["ffmpeg", "-y", "-f", "fbdev", "-i", "/dev/fb0", "-frames:v", "1", out],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        log(f"스크린샷 시도: {out}")
    except OSError as e:
        log(f"ffmpeg 실행 실패: {e}")


def exit_session(target_pid):
    try:
        pgid = os.getpgid(target_pid)
    except ProcessLookupError:
        return
    try:
        os.killpg(pgid, signal.SIGTERM)
        log(f"종료 신호 전송 (pgid={pgid})")
    except ProcessLookupError:
        pass


def watch(name, event_path, codes, target_pid):
    select_code = codes.get("select")
    start_code = codes.get("start")
    pageup_code = codes.get("pageup")
    if select_code is None:
        log(f"{name}: es_input.cfg에 select 매핑 없음 - 감시 안 함")
        return

    log(
        f"감시 시작: {name} ({event_path}) "
        f"select={select_code} start={start_code} pageup={pageup_code}"
    )

    try:
        fd = os.open(event_path, os.O_RDONLY)
    except OSError as e:
        log(f"{event_path} 열기 실패: {e}")
        return

    held = set()
    exit_fired = False
    screenshot_fired = False

    while True:
        try:
            data = os.read(fd, EVENT_SIZE)
        except OSError:
            break
        if len(data) < EVENT_SIZE:
            break

        _, _, ev_type, code, value = struct.unpack(EVENT_FMT, data)
        if ev_type != EV_KEY:
            continue

        if value == 1:
            held.add(code)
        elif value == 0:
            held.discard(code)
            exit_fired = False
            screenshot_fired = False
            continue
        else:
            continue  # 키 반복(auto-repeat)은 무시

        if start_code is not None and select_code in held and start_code in held:
            if not exit_fired:
                exit_fired = True
                exit_session(target_pid)
        elif pageup_code is not None and select_code in held and pageup_code in held:
            if not screenshot_fired:
                screenshot_fired = True
                take_screenshot()


def main():
    if len(sys.argv) < 2:
        log("Usage: rpui-termkeys.py <target_pid>")
        sys.exit(1)
    target_pid = int(sys.argv[1])

    joysticks = detect_joysticks()
    if not joysticks:
        log("연결된 조이스틱 없음 - 감시 안 함")
        return

    # 여러 개 연결돼 있으면 첫 번째 것만 감시(rpui-launcher.py의
    # 핫키 오버라이드도 동일하게 첫 번째 매칭 장치 기준).
    name, event_path = joysticks[0]
    codes = find_codes_for_device(name, ("select", "start", "pageup"))
    if not codes:
        log(f"{name}: es_input.cfg에 매핑 없음 - 감시 안 함")
        return

    watch(name, event_path, codes, target_pid)


if __name__ == "__main__":
    main()
