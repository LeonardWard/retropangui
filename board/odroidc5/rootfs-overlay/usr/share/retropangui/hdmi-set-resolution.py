#!/usr/bin/env python3
# hdmi-set-resolution.py
#
# retropangui.conf의 system.hdmi_resolution 값에 따라 실제 사용할 HDMI
# 출력 모드 이름을 stdout으로 한 줄 출력한다(호출부가 odroid-drm-fbset
# -outputmode <값> 에 그대로 넘겨 쓰는 용도).
#
#   auto (기본값)  : 연결된 모니터의 EDID preferred(네이티브) 타이밍을 읽어
#                    커스텀 모드라인으로 등록하고 그 모드 이름을 출력한다.
#                    파싱 실패/이상값/이미 1920x1080인 경우는 그냥
#                    "1920x1080p60hz"를 출력한다(항상 존재가 보장된 CEA 모드).
#   그 외 값       : odroid-drm-fbset이 이미 아는 CEA 모드 이름(예:
#                    1920x1080p60hz, 1280x720p60hz)이라고 보고 그대로 출력.
#
# 진단 로그는 stderr로만 나가고, stdout은 항상 모드 이름 한 줄만 낸다 -
# 무슨 일이 있어도(EDID 없음, 파싱 실패, 파일 접근 오류 등) 최종적으로
# "1920x1080p60hz"를 출력해서 절대 부팅을 막지 않는다.
#
# 2026-07-11: 예전에 EDID "preferred"를 그대로 믿고 걸었다가 일부 모니터/TV가
# 120Hz로 잡혀서 화면이 안 나오는 사고가 있었음(S99emulationstation 주석
# 참고) - 그래서 여기서는 계산된 새로고침율이 55~61Hz 범위를 벗어나면
# 무조건 안전한 기본값으로 폴백한다(자동 감지 결과를 refresh rate 기준으로
# 검증하는 안전장치).

import sys
import os

CONF_FILE = "/retropangui/share/system/retropangui.conf"
EDID_PATH = "/sys/class/drm/card0-HDMI-A-A/edid"
MODELINE_PARAM = "/sys/module/aml_drm/parameters/modeline"
DISPLAYMODE_PARAM = "/sys/module/aml_drm/parameters/displaymode"
FALLBACK_MODE = "1920x1080p60hz"


def log(msg):
    print(f"[hdmi-set-resolution] {msg}", file=sys.stderr)


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


def parse_dtd(b):
    """18바이트 EDID Detailed Timing Descriptor를 파싱한다."""
    pclk_khz = (b[0] | (b[1] << 8)) * 10
    hactive = b[2] | ((b[4] >> 4) << 8)
    hblank = b[3] | ((b[4] & 0xF) << 8)
    vactive = b[5] | ((b[7] >> 4) << 8)
    vblank = b[6] | ((b[7] & 0xF) << 8)
    hfront = b[8] | (((b[11] >> 6) & 0x3) << 8)
    hsync = b[9] | (((b[11] >> 4) & 0x3) << 8)
    vfront = (b[10] >> 4) | (((b[11] >> 2) & 0x3) << 4)
    vsync = (b[10] & 0xF) | (((b[11] >> 0) & 0x3) << 4)
    return dict(pclk_khz=pclk_khz, hactive=hactive, hblank=hblank,
                vactive=vactive, vblank=vblank, hfront=hfront,
                hsync=hsync, vfront=vfront, vsync=vsync)


def get_preferred_mode():
    """EDID 베이스 블록의 첫 번째 DTD(오프셋 54, 항상 preferred)를 읽어
    (modeline_str, mode_name, hactive, vactive, refresh) 튜플을 돌려준다.
    실패/이상값이면 None."""
    try:
        with open(EDID_PATH, "rb") as f:
            data = f.read()
    except OSError as e:
        log(f"EDID 읽기 실패: {e}")
        return None

    if len(data) < 72 or data[0:8] != bytes([0, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0]):
        log("EDID 헤더가 이상함 - 폴백")
        return None

    d = parse_dtd(data[54:72])

    if d["pclk_khz"] == 0 or d["hactive"] == 0 or d["vactive"] == 0:
        log("preferred DTD가 비어있음(0) - 폴백")
        return None

    # 상식적인 범위 밖이면(깨진 EDID 등) 폴백
    if not (640 <= d["hactive"] <= 3840) or not (480 <= d["vactive"] <= 2160):
        log(f"해상도 범위 밖: {d['hactive']}x{d['vactive']} - 폴백")
        return None

    htotal = d["hactive"] + d["hblank"]
    vtotal = d["vactive"] + d["vblank"]
    hsync_start = d["hactive"] + d["hfront"]
    hsync_end = hsync_start + d["hsync"]
    vsync_start = d["vactive"] + d["vfront"]
    vsync_end = vsync_start + d["vsync"]
    clock_mhz = d["pclk_khz"] / 1000.0

    if htotal == 0 or vtotal == 0:
        log("total이 0 - 폴백")
        return None

    refresh = (d["pclk_khz"] * 1000.0) / (htotal * vtotal)

    # 2026-07-11: 예전 120Hz 자동협상 사고 재발 방지 - 55~61Hz 범위 밖이면
    # 이 EDID의 preferred를 못 믿는 걸로 보고 폴백.
    if not (55.0 <= refresh <= 61.0):
        log(f"새로고침율이 안전 범위 밖: {refresh:.2f}Hz - 폴백")
        return None

    if d["hactive"] == 1920 and d["vactive"] == 1080:
        log("preferred가 이미 1920x1080 - 커스텀 모드 불필요")
        return None

    name = f"custom_{d['hactive']}x{d['vactive']}"
    modeline = (
        f'Modeline "{name}" {clock_mhz:.3f} '
        f'{d["hactive"]} {hsync_start} {hsync_end} {htotal} '
        f'{d["vactive"]} {vsync_start} {vsync_end} {vtotal} '
        f'+hsync +vsync'
    )
    return modeline, name, d["hactive"], d["vactive"], refresh


def main():
    requested = read_conf_value("system.hdmi_resolution", "auto")

    if requested and requested != "auto":
        log(f"수동 지정 모드 사용: {requested}")
        print(requested)
        return

    result = get_preferred_mode()
    if result is None:
        print(FALLBACK_MODE)
        return

    modeline, name, w, h, refresh = result
    log(f"EDID 네이티브 감지: {w}x{h}@{refresh:.2f}Hz -> {name}")

    try:
        with open(MODELINE_PARAM, "w") as f:
            f.write(modeline)
        with open(DISPLAYMODE_PARAM, "w") as f:
            f.write(name)
    except OSError as e:
        log(f"모드라인 등록 실패({e}) - 폴백")
        print(FALLBACK_MODE)
        return

    print(name)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log(f"예외 발생({e}) - 폴백")
        print(FALLBACK_MODE)
