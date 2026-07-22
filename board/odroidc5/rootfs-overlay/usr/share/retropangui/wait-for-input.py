#!/usr/bin/python3
"""RetroPangui: 모든 /dev/input/eventN에서 진짜 키/버튼 눌림(EV_KEY, value=1)이
올 때까지 블로킹. web-stream-screensaver.sh가 사용.

dd로 32바이트 읽기만 했을 때는 장치를 열자마자 커널이 보내는 초기 상태
리포트(EV_SYN 등)에 곧바로 반응해버려서 mpv가 뜨자마자 바로 꺼지는 문제가
있었음(2026-07-23 실기기 확인) - 그래서 먼저 논블로킹으로 기존에 쌓여있던
이벤트를 전부 비우고, 그 뒤 select()로 새로 들어오는 이벤트만 기다리며
EV_KEY(type=1) + value=1(눌림, 뗌/리피트 제외)만 실제 입력으로 인정한다.
"""
import fcntl
import glob
import os
import select
import struct
import sys

EVENT_FORMAT = "llHHi"  # struct input_event: timeval(long,long) + type,code(H,H) + value(i)
EVENT_SIZE = struct.calcsize(EVENT_FORMAT)
EV_KEY = 1

fds = []
for path in glob.glob("/dev/input/event*"):
    try:
        fds.append(open(path, "rb", buffering=0))
    except OSError:
        pass

if not fds:
    sys.exit(0)

# 오픈 직후 남아있는 기존 이벤트 전부 비우기(논블로킹)
for f in fds:
    flags = fcntl.fcntl(f, fcntl.F_GETFL)
    fcntl.fcntl(f, fcntl.F_SETFL, flags | os.O_NONBLOCK)
    try:
        while f.read(EVENT_SIZE):
            pass
    except OSError:
        pass
    fcntl.fcntl(f, fcntl.F_SETFL, flags)

# 진짜 새 입력만 기다림
while True:
    ready, _, _ = select.select(fds, [], [])
    for f in ready:
        data = f.read(EVENT_SIZE)
        if not data or len(data) < EVENT_SIZE:
            continue
        _, _, ev_type, _, ev_value = struct.unpack(EVENT_FORMAT, data)
        if ev_type == EV_KEY and ev_value == 1:
            sys.exit(0)
