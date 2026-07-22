#!/usr/bin/env python3
"""웹 스트림 스크린세이버 - cog(wpewebkit)로 C5가 웹페이지를 직접 DRM에 렌더링.

2026-07-23: 기존엔 클라우드 서버(Xvfb+Chromium+ffmpeg)가 화면을 캡처해서
HTTP 스트림으로 보내고 C5는 mpv로 그 스트림만 재생하는 구조였는데, 사용자
지시로 외부 서버 의존을 걷어내고 C5가 직접 렌더링하도록 전환("c5내장").
terminal.py/wait-for-input.py와 동일하게 - 실행 파일 하나 + 검증된
wait-for-input.py 재사용 + ES 화면보호 항목과 매칭 호출이라는 심플한 패턴을
그대로 따름.

SystemScreenSaver.cpp가 launchGame()과 동일한 패턴으로 window/input/audio를
전부 deinit한 뒤 인자 없이 이 스크립트만 실행함 - URL 목록/순환 주기는
여기서 retropangui.conf를 직접 읽는다(ES Settings를 거치지 않음, 별도 동기화
서버도 불필요).
"""
import os
import subprocess
import sys
import time

CONF_FILE = "/retropangui/share/system/retropangui.conf"
DRM_DEVICE = "/dev/dri/card0"
LOG_FILE = "/var/log/web-stream-screensaver.log"
DEFAULT_INTERVAL = 120


def log(msg):
    try:
        with open(LOG_FILE, "a") as f:
            f.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {msg}\n")
    except OSError:
        pass


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


def read_urls():
    raw = read_conf_value("screensaver.web_stream_urls", "")
    urls = [u.strip() for u in raw.split(",") if u.strip()]
    return urls


def read_interval():
    raw = read_conf_value("screensaver.web_stream_interval", str(DEFAULT_INTERVAL))
    try:
        v = int(raw)
        return v if v > 0 else DEFAULT_INTERVAL
    except ValueError:
        return DEFAULT_INTERVAL


def wait_for_exit_or_timeout(cog_proc, waiter_proc, timeout_s):
    """cog가 죽거나(크래시), 입력이 감지되거나(waiter 종료), timeout이 지날 때까지 대기.
    반환값: "input" | "timeout" | "crash" """
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        if cog_proc.poll() is not None:
            return "crash"
        if waiter_proc.poll() is not None:
            return "input"
        time.sleep(0.3)
    return "timeout"


def kill_proc(proc):
    if proc is None or proc.poll() is not None:
        return
    try:
        proc.terminate()
        proc.wait(timeout=2)
    except (ProcessLookupError, subprocess.TimeoutExpired):
        try:
            proc.kill()
            proc.wait(timeout=2)
        except Exception:
            pass


def main():
    urls = read_urls()
    if not urls:
        log("설정된 URL 없음(screensaver.web_stream_urls 비어있음) - 즉시 종료")
        return

    interval = read_interval()
    log(f"시작 - URL {len(urls)}개, 순환 주기 {interval}초")

    idx = 0
    with open(LOG_FILE, "a") as logf:
        while True:
            url = urls[idx % len(urls)]
            idx += 1
            log(f"로딩: {url}")

            cog_proc = subprocess.Popen(
                ["cog", "--platform=drm", url],
                stdout=logf, stderr=subprocess.STDOUT,
                env={**os.environ, "COG_PLATFORM_DRM_DEVICE": DRM_DEVICE},
            )

            # mpv 스크립트와 동일한 이유(DRM 모드셋 완료 전 조기 종료 경합 방지) -
            # cog가 완전히 화면을 잡을 시간을 준 뒤에야 입력 감지를 시작.
            time.sleep(2)

            waiter_proc = subprocess.Popen(
                ["python3", "/usr/share/retropangui/wait-for-input.py"],
            )

            reason = wait_for_exit_or_timeout(cog_proc, waiter_proc, interval)

            kill_proc(waiter_proc)
            kill_proc(cog_proc)
            # mpv 스크립트와 동일 - DRM master를 완전히 내려놓을 시간
            time.sleep(0.5)

            if reason == "input":
                log("입력 감지 - 스크린세이버 종료")
                return
            if reason == "crash":
                log(f"cog 비정상 종료(url={url}) - 다음 URL로 계속")
                time.sleep(1)
            else:
                log(f"주기 만료({interval}s) - 다음 URL로 전환")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log(f"예외 발생: {e}")
        sys.exit(0)
