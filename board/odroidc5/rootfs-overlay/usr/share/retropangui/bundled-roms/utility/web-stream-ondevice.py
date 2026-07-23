#!/usr/bin/env python3
"""웹 스트림(온디바이스 브라우징) - Utility 시스템 항목 + 스크린세이버 공용 스크립트.

cog(wpewebkit)로 C5가 웹페이지를 직접 DRM에 렌더링(외부 서버 없이 "c5내장").

⏸️ 2026-07-23 기준 보류 상태: 실기기에서 WPEWebProcess가 mali_buffer_sharing
프로토콜 협상 실패로 어떤 페이지든(about:blank 포함) 즉시 크래시함. Mali GPU +
cog의 GPU 버퍼공유는 Igalia(WPE 개발사) 상류에서도 여러 Mali 세대에 걸쳐
수년째 미해결인 구조적 문제로 확인됨 - 자세한 내용/재개 조건은
docs/retropangui/todo-20260723-news-ticker.html의 "온디바이스 전환 시도"
섹션 참고. 코드/유틸리티 등록은 상류 이슈 해결 시 바로 재검증할 수 있도록
그대로 보존.

터미널 실행 방식(terminal.py)과 동일 패턴 - 실행 파일 하나 + 검증된
wait-for-input.py 재사용 + ES 화면보호 항목과 매칭 호출.

URL 목록/순환 주기는 retropangui.conf를 직접 읽는다(ES Settings를 거치지
않음, 별도 동기화 서버도 불필요). ES의 launchGame()/SystemScreenSaver 양쪽
다 이 스크립트 실행 전후로 window/input/audio deinit/init을 처리해주므로
이 스크립트는 재생과 종료 감지만 담당하면 된다.
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
