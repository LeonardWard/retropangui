#!/usr/bin/env python3
"""뉴스 티커(API 이용 내부 처리) - Utility 시스템 항목 + 스크린세이버 공용 스크립트.

브라우저 렌더링 없이, rpui-ticker-fetch.py(별도 상주 데몬, 미착수)가 API로
수집해서 /var/lib/retropangui/ticker-data.json에 저장해둔 코스피/코스닥/
날씨/뉴스 데이터를 Pillow로 PNG에 그려서 mpv --vo=drm으로 표시한다
(스크린샷 뷰어 rpui-imgview.sh와 동일한 "이미지 생성 후 mpv로 DRM 표시" 패턴 -
브라우저/GPU 가속 문제를 원천적으로 피할 수 있음).

터미널 실행 방식(terminal.py)과 동일 패턴 - 실행 파일 하나 + 검증된
wait-for-input.py 재사용 + ES 화면보호 항목과 매칭 호출. ES의
launchGame()/SystemScreenSaver 양쪽 다 이 스크립트 실행 전후로
window/input/audio deinit/init을 처리해주므로 이 스크립트는 표시와 종료
감지만 담당하면 된다.

데이터 파일이 없거나 API 키가 하나도 없으면(rpui-ticker-fetch.py 미착수
상태 포함) 안내 화면만 그리고 정상 종료 조건(입력 감지)까지 그대로 대기함
- 빈 화면/크래시 방지.
"""
import json
import os
import subprocess
import sys
import time

DATA_FILE = "/var/lib/retropangui/ticker-data.json"
IMG_FILE = "/tmp/rpui-news-ticker.png"
FONT_PATH = "/usr/share/fonts/truetype/pretendard/Pretendard-Regular.ttf"
LOG_FILE = "/var/log/news-ticker.log"
CANVAS = (1920, 1080)
REFRESH_INTERVAL = 60  # 화면 갱신 주기(초) - 데이터 파일을 다시 읽어서 재렌더링


def log(msg):
    try:
        with open(LOG_FILE, "a") as f:
            f.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {msg}\n")
    except OSError:
        pass


def load_data():
    try:
        with open(DATA_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return None


def render_image(data):
    from PIL import Image, ImageDraw, ImageFont

    img = Image.new("RGB", CANVAS, color=(15, 17, 23))
    draw = ImageDraw.Draw(img)

    font_title = ImageFont.truetype(FONT_PATH, 64)
    font_label = ImageFont.truetype(FONT_PATH, 36)
    font_value = ImageFont.truetype(FONT_PATH, 72)
    font_news = ImageFont.truetype(FONT_PATH, 32)

    x, y = 80, 60
    draw.text((x, y), time.strftime("%Y년 %m월 %d일 %H:%M"), font=font_title, fill=(240, 246, 252))
    y += 120

    if not data:
        draw.text((x, y), "설정 필요", font=font_title, fill=(227, 179, 65))
        y += 90
        draw.text((x, y), "SYSTEM SETTINGS > TICKER SETTINGS 에서", font=font_label, fill=(139, 148, 158))
        y += 50
        draw.text((x, y), "네이버 / KRX / 기상청 API 키를 입력해 주세요.", font=font_label, fill=(139, 148, 158))
        img.save(IMG_FILE)
        return

    def stat_block(x0, y0, label, value, color):
        draw.text((x0, y0), label, font=font_label, fill=(139, 148, 158))
        draw.text((x0, y0 + 50), value, font=font_value, fill=color)

    kospi = data.get("kospi")
    kosdaq = data.get("kosdaq")
    if kospi or kosdaq:
        if kospi:
            stat_block(x, y, "코스피 KOSPI", str(kospi.get("value", "-")), (63, 185, 80))
        if kosdaq:
            stat_block(x + 700, y, "코스닥 KOSDAQ", str(kosdaq.get("value", "-")), (88, 166, 255))
        y += 160

    weather = data.get("weather")
    if weather:
        stat_block(x, y, "날씨", str(weather.get("summary", "-")), (240, 136, 62))
        y += 160

    news = data.get("news") or []
    if news:
        draw.text((x, y), "뉴스 헤드라인", font=font_label, fill=(139, 148, 158))
        y += 50
        for headline in news[:6]:
            draw.text((x, y), f"· {headline}", font=font_news, fill=(201, 209, 217))
            y += 46

    img.save(IMG_FILE)


def wait_for_exit_or_timeout(mpv_proc, waiter_proc, timeout_s):
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        if mpv_proc.poll() is not None:
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
    log("시작")

    waiter_proc = subprocess.Popen(
        ["python3", "/usr/share/retropangui/wait-for-input.py"],
    )

    mpv_proc = None
    try:
        while True:
            render_image(load_data())

            kill_proc(mpv_proc)
            mpv_proc = subprocess.Popen(
                ["mpv", "--loop-file=inf", "--vo=drm", "--drm-device=/dev/dri/card0",
                 "--no-audio", "--really-quiet", IMG_FILE],
            )
            time.sleep(2)

            reason = wait_for_exit_or_timeout(mpv_proc, waiter_proc, REFRESH_INTERVAL)
            if reason == "input":
                log("입력 감지 - 종료")
                break
            if reason == "crash":
                log("mpv 비정상 종료 - 재시도")
                time.sleep(1)
            else:
                log("갱신 주기 도달 - 데이터 재로드")
    finally:
        kill_proc(mpv_proc)
        kill_proc(waiter_proc)
        time.sleep(0.5)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log(f"예외 발생: {e}")
        sys.exit(0)
