#!/usr/bin/env python3
"""
rpui-imgviewkeys - 스크린샷 뷰어(mpv) 종료 패드 감시.

패드의 "b"(뒤로가기) 버튼을 누르면 뷰어를 끄고 ES로 복귀시킨다. 버튼의
evdev 코드는 패드마다 다르므로 es_input.cfg에서 그대로 읽어서 쓴다
(rpui-termkeys.py와 동일한 방식, 2026-07-06).

rpui-imgview.sh가 백그라운드로 띄우고, 인자로 mpv 프로세스의 PID를 받는다.
"""
import os
import signal
import struct
import sys

sys.path.insert(0, "/usr/share/retropangui")
from rpui_padutil import detect_joysticks, find_codes_for_device  # noqa: E402

EVENT_FMT = "llHHi"
EVENT_SIZE = struct.calcsize(EVENT_FMT)
EV_KEY = 1


def log(msg):
    print(f"[imgviewkeys] {msg}", file=sys.stderr, flush=True)


def watch(name, event_path, b_code, target_pid):
    log(f"감시 시작: {name} ({event_path}) b={b_code}")
    try:
        fd = os.open(event_path, os.O_RDONLY)
    except OSError as e:
        log(f"{event_path} 열기 실패: {e}")
        return

    while True:
        try:
            data = os.read(fd, EVENT_SIZE)
        except OSError:
            break
        if len(data) < EVENT_SIZE:
            break

        _, _, ev_type, code, value = struct.unpack(EVENT_FMT, data)
        if ev_type != EV_KEY or value != 1 or code != b_code:
            continue

        try:
            os.kill(target_pid, signal.SIGTERM)
            log(f"종료 신호 전송 (pid={target_pid})")
        except ProcessLookupError:
            pass
        return


def main():
    if len(sys.argv) < 2:
        log("Usage: rpui-imgviewkeys.py <mpv_pid>")
        sys.exit(1)
    target_pid = int(sys.argv[1])

    joysticks = detect_joysticks()
    if not joysticks:
        log("연결된 조이스틱 없음 - 감시 안 함")
        return

    name, event_path = joysticks[0]
    codes = find_codes_for_device(name, ("b",))
    b_code = codes.get("b")
    if b_code is None:
        log(f"{name}: es_input.cfg에 b 매핑 없음 - 감시 안 함")
        return

    watch(name, event_path, b_code, target_pid)


if __name__ == "__main__":
    main()
