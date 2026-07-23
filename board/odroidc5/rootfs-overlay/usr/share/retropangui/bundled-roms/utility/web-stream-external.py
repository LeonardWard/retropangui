#!/usr/bin/env python3
"""웹 스트림(외부 서버 브라우징) - Utility 시스템 항목 + 스크린세이버 공용 스크립트.

외부 서버(Xvfb+Chromium+ffmpeg, ~/scripts/rpui-web-stream-external-server.sh로
관리)가 송출하는 HTTP 스트림을 mpv로 DRM에 직접 재생한다. URL 순환은 서버
쪽 책임이라 여기서는 retropangui.conf의 emulationstation.WebStreamUrl(고정
스트림 주소) 하나만 재생하면 된다.

2026-07-23: 유틸리티 시스템 ROM으로도 등록해서(gamelist.xml) 화면보호기
자동 트리거 없이도 언제든 수동으로 바로 실행/검증할 수 있게 함. ES의
launchGame()이 이 스크립트 실행 전후로 window/input/audio deinit/init을
이미 처리해주므로(terminal.py와 동일 패턴) 이 스크립트는 재생과 종료
감지만 담당하면 된다. SystemScreenSaver.cpp도 같은 deinit/exec/reinit
시퀀스로 이 스크립트를 그대로 재사용한다.
"""
import subprocess
import sys
import time

CONF_FILE = "/retropangui/share/system/retropangui.conf"


def read_conf_value(key, default=""):
    try:
        with open(CONF_FILE, "r") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" not in line:
                    continue
                k, v = line.split("=", 1)
                if k.strip() == key:
                    return v.strip()
    except OSError:
        pass
    return default


def main():
    url = read_conf_value("emulationstation.WebStreamUrl")
    if not url:
        print("emulationstation.WebStreamUrl 설정 없음 - 종료", file=sys.stderr)
        return

    mpv_proc = subprocess.Popen(
        ["mpv", "--vo=drm", "--drm-device=/dev/dri/card0", "--loop=inf",
         "--no-input-terminal", "--really-quiet", url],
    )

    # mpv가 DRM 모드셋을 끝낼 시간 - 조기 종료 감지 경합 방지(web-stream-ondevice.py와 동일 이유)
    time.sleep(2)

    waiter_proc = subprocess.Popen(
        ["python3", "/usr/share/retropangui/wait-for-input.py"],
    )

    while mpv_proc.poll() is None and waiter_proc.poll() is None:
        time.sleep(0.3)

    for p in (mpv_proc, waiter_proc):
        if p.poll() is None:
            p.terminate()
    for p in (mpv_proc, waiter_proc):
        try:
            p.wait(timeout=2)
        except subprocess.TimeoutExpired:
            p.kill()

    # DRM master를 완전히 내려놓을 시간
    time.sleep(0.5)


if __name__ == "__main__":
    main()
