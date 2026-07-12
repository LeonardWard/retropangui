#!/usr/bin/env python3
# hdmi-set-resolution.py
#
# 두 가지 용도로 쓰인다:
#
#   (인자 없음) retropangui.conf의 system.hdmi_resolution 값에 따라 실제
#       사용할 HDMI 출력 모드 이름을 stdout으로 한 줄 출력한다(호출부가
#       odroid-drm-fbset -outputmode <값>에 그대로 넘겨 씀).
#       - auto(기본값): EDID의 preferred(네이티브) 타이밍을 그대로 사용.
#       - "WIDTHxHEIGHT"(예: 2560x1600): EDID가 실제로 신고한 후보 중
#         일치하는 걸 찾아 그 타이밍으로 등록.
#       - 그 외: odroid-drm-fbset이 이미 아는 CEA 모드 이름(예:
#         1080p60hz)이라고 보고 그대로 출력(수동 폴백용).
#
#   --list  지금 연결된 모니터의 EDID에서 실제로 뽑아낸 해상도 후보
#       목록을 JSON으로 stdout에 출력한다(부작용 없음 - 모드라인 등록
#       안 함). ES의 SYSTEM SETTINGS > OUTPUT RESOLUTION 메뉴가 이 출력을
#       그대로 읽어서 선택지를 만든다(2026-07-12, 고정 목록 대신 EDID가
#       실제로 신고한 값만 보여달라는 요청 반영).
#
# 진단 로그는 stderr로만 나가고, (인자 없음) 모드의 stdout은 항상 모드
# 이름 한 줄만 낸다 - 무슨 일이 있어도(EDID 없음, 파싱 실패, 파일 접근
# 오류 등) 최종적으로 "1080p60hz"를 출력해서 절대 부팅을 막지 않는다.
#
# 2026-07-12 정정: 예전엔 이 폴백 이름이 "1920x1080p60hz"였는데, 이건
# U-Boot 부팅 파라미터(boot.cmd의 vout=1920x1080p60hz) 표기를 그대로
# 가져온 실수였음 - odroid-drm-fbset -showmodes로 실제 DRM 커넥터가
# 등록한 모드 이름을 확인해보면 "1080p60hz"/"720p60hz"(WxH 접두어 없음)
# 이지 "1920x1080p60hz"/"1280x720p60hz"가 아님. 두 네임스페이스가 다른데
# 섞어 써서, 이 폴백이 실제로 걸리는 상황(EDID 실패 등)에서 존재하지
# 않는 모드 이름으로 odroid-drm-fbset을 호출해 조용히 실패하고 있었음
# (사용자가 OUTPUT RESOLUTION에서 1280x720을 골랐는데 실제로는 안 바뀌고
# 이전 해상도가 그대로 유지되는 걸로 발견됨).
#
# 2026-07-11: 예전에 EDID "preferred"를 그대로 믿고 걸었다가 일부 모니터/TV가
# 120Hz로 잡혀서 화면이 안 나오는 사고가 있었음(S99emulationstation 주석
# 참고) - 그래서 여기서는 계산된 새로고침율이 55~61Hz 범위를 벗어나면
# 무조건 안전한 기본값으로 폴백한다(자동 감지 결과를 refresh rate 기준으로
# 검증하는 안전장치). --list로 보여주는 후보 목록도 동일하게 이 범위
# 밖인 건 아예 제외한다.

import sys
import json
import hashlib

CONF_FILE = "/retropangui/share/system/retropangui.conf"
# 2026-07-13: EDID 소스를 DRM sysfs에서 amhdmitx rawedid(hex 텍스트)로 변경.
# DRM 쪽(/sys/class/drm/card0-HDMI-A-A/edid)은 커넥터를 누가 probe할 때만
# 갱신되는 캐시라서, 모니터를 핫플러그로 교체한 직후엔 "이전 모니터"의
# EDID를 그대로 보여줌(실기기에서 모니터 교체로 실측 - amhdmitx는 SAC 신형을
# 읽었는데 DRM은 ZEUSLAP 것을 유지). rawedid는 드라이버가 플러그인 때마다
# 새로 읽는 원본이라 항상 신선함.
RAWEDID_PATH = "/sys/class/amhdmitx/amhdmitx0/rawedid"
EDID_DRM_FALLBACK = "/sys/class/drm/card0-HDMI-A-A/edid"
EDID_BASELINE = "/var/run/hdmi-edid.sha"
MODELINE_PARAM = "/sys/module/aml_drm/parameters/modeline"
DISPLAYMODE_PARAM = "/sys/module/aml_drm/parameters/displaymode"
FALLBACK_MODE = "1080p60hz"
MIN_REFRESH = 55.0
MAX_REFRESH = 61.0

# 2026-07-12: EDID가 신고 안 하는 종횡비(16:10/4:3)를 위한 고정 폴백들 -
# odroid-drm-fbset이 아는 CEA 모드가 아니라서 EDID 조회 없이 바로 등록
# 가능한, 업계에 널리 검증된 표준 모드라인만 골라서 박아둠(CVT-RB로
# 새로 계산한 값은 신뢰도 검증이 안 돼서 안 씀 - 1600x900/1366x768 등을
# 시도했다가 역산해보니 새로고침율이 틀려서 뺐음, 2026-07-12).
#   - 1920x1200 (16:10): CVT-RB 표준값, 역산 검증 완료(~59.95Hz)
#   - 1024x768  (4:3)  : VESA DMT 표준값(수십 년간 쓰인 고전 XGA 타이밍),
#     역산 검증 완료(~60.00Hz)
FALLBACK_CUSTOM_MODES = {
    "fallback_1920x1200p60hz": {
        "name": "fallback_1920x1200p60hz",
        "width": 1920, "height": 1200,
        "modeline": 'Modeline "fallback_1920x1200p60hz" 154.000 '
                    '1920 1968 2000 2080 1200 1203 1209 1235 -hsync +vsync',
    },
    "fallback_1024x768p60hz": {
        "name": "fallback_1024x768p60hz",
        "width": 1024, "height": 768,
        "modeline": 'Modeline "fallback_1024x768p60hz" 65.000 '
                    '1024 1048 1184 1344 768 771 777 806 -hsync -vsync',
    },
}


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
    """18바이트 EDID Detailed Timing Descriptor를 파싱한다. Descriptor가
    아니면(하위 2바이트가 0) None."""
    if b[0] == 0 and b[1] == 0:
        return None
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


def build_candidate(d, preferred=False):
    """parse_dtd() 결과를 실제 사용 가능한 후보(dict)로 변환. 명백히 깨진
    값(0, 상식 밖 해상도)만 걸러내고, 새로고침율은 얼마가 나오든 그대로
    둔다 - 2026-07-12: "필터링하지 말고 EDID가 신고하는 대로 그대로
    보여달라"는 요청 반영. 새로고침율 안전 필터는 auto(무인 부팅) 경로에만
    별도로 적용한다(get_safe_candidates() 참고)."""
    if d is None or d["pclk_khz"] == 0 or d["hactive"] == 0 or d["vactive"] == 0:
        return None
    if not (640 <= d["hactive"] <= 3840) or not (480 <= d["vactive"] <= 2160):
        return None

    htotal = d["hactive"] + d["hblank"]
    vtotal = d["vactive"] + d["vblank"]
    if htotal == 0 or vtotal == 0:
        return None

    hsync_start = d["hactive"] + d["hfront"]
    hsync_end = hsync_start + d["hsync"]
    vsync_start = d["vactive"] + d["vfront"]
    vsync_end = vsync_start + d["vsync"]
    clock_mhz = d["pclk_khz"] / 1000.0
    refresh = (d["pclk_khz"] * 1000.0) / (htotal * vtotal)
    refresh_rounded = round(refresh)

    name = f"custom_{d['hactive']}x{d['vactive']}_{refresh_rounded}hz"
    modeline = (
        f'Modeline "{name}" {clock_mhz:.3f} '
        f'{d["hactive"]} {hsync_start} {hsync_end} {htotal} '
        f'{d["vactive"]} {vsync_start} {vsync_end} {vtotal} '
        f'+hsync +vsync'
    )
    return dict(name=name, width=d["hactive"], height=d["vactive"],
                refresh=refresh, refresh_rounded=refresh_rounded,
                modeline=modeline, preferred=preferred)


def read_edid():
    # rawedid(hex 텍스트) 우선 - 핫플러그 직후에도 항상 현재 모니터의 EDID.
    try:
        with open(RAWEDID_PATH, "r") as f:
            hex_text = f.read().strip()
        if len(hex_text) >= 256:  # 최소 EDID 1블록(128바이트=256hex)
            return bytes.fromhex(hex_text)
    except (OSError, ValueError) as e:
        log(f"rawedid 읽기 실패({e}) - DRM sysfs로 폴백")
    try:
        with open(EDID_DRM_FALLBACK, "rb") as f:
            return f.read()
    except OSError as e:
        log(f"EDID 읽기 실패: {e}")
        return None


def get_candidates():
    """EDID에서 뽑아낸 해상도 후보를 preferred 우선, 그다음 해상도·새로고침율
    내림차순으로 정렬해서 돌려준다. 2026-07-12: 걸러내지 말고 EDID가
    신고하는 DTD를 있는 그대로 다 보여달라는 요청 - 새로고침율/1920x1080
    여부로 제외하지 않음. (해상도, 반올림한 새로고침율)이 완전히 같은
    DTD만 중복으로 보고 첫 번째(더 앞순위) 것만 남김."""
    data = read_edid()
    if data is None or len(data) < 128 or data[0:8] != bytes([0, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0]):
        log("EDID 헤더가 이상함")
        return []

    raw = []
    # 베이스 블록의 DTD 4개(오프셋 54/72/90/108) - 첫 번째가 항상 preferred.
    for i, off in enumerate((54, 72, 90, 108)):
        c = build_candidate(parse_dtd(data[off:off + 18]), preferred=(i == 0))
        if c:
            raw.append(c)

    # CTA-861 확장 블록(있으면, 오프셋 128부터) - 자체 DTD들도 후보에 추가.
    if len(data) >= 256 and data[128] == 0x02:
        ext = data[128:256]
        dtd_start = ext[2]
        off2 = dtd_start
        while 0 < off2 < 127 and ext[off2] != 0 and off2 + 18 <= 128:
            c = build_candidate(parse_dtd(ext[off2:off2 + 18]))
            if c:
                raw.append(c)
            off2 += 18

    seen = set()
    candidates = []
    for c in raw:
        key = (c["width"], c["height"], c["refresh_rounded"])
        if key in seen:
            continue
        seen.add(key)
        candidates.append(c)

    candidates.sort(key=lambda c: (not c["preferred"], -(c["width"] * c["height"]), -c["refresh"]))
    return candidates


def get_safe_auto_candidate(candidates):
    """auto(무인 부팅) 경로 전용 - 55~61Hz 범위 밖은 예전 120Hz 자동협상
    사고 재발 방지를 위해 여기서만 걸러냄. preferred가 범위 밖이면 범위
    안에 드는 다음 후보로 대체."""
    for c in candidates:
        if MIN_REFRESH <= c["refresh"] <= MAX_REFRESH:
            return c
    return None


def cmd_list():
    candidates = get_candidates()
    print(json.dumps(candidates))


def apply_candidate(c):
    try:
        with open(MODELINE_PARAM, "w") as f:
            f.write(c["modeline"])
        with open(DISPLAYMODE_PARAM, "w") as f:
            f.write(c["name"])
    except OSError as e:
        log(f"모드라인 등록 실패({e}) - 폴백")
        print(FALLBACK_MODE)
        return
    print(c["name"])


def refresh_custom_slot(candidates):
    # CEA/고정 폴백 경로 전용. aml_drm의 커스텀 모드라인 슬롯은 하나뿐이고
    # 모니터를 바꿔도 이전 모니터용 등록이 그대로 남아 preferred 플래그를
    # 계속 차지함(2026-07-13 실측: ZEUSLAP용 custom_2560x1600이 SAC 연결
    # 후에도 preferred로 남아 mpv/kodi의 preferred 선택을 오염 - SAC에서
    # 신호 없음 유발). 커스텀 모드를 적용하지 않는 경로에서도 현재 모니터의
    # 안전한 preferred로 슬롯을 다시 채워서 죽은 모드가 남지 않게 한다.
    # 주의: 재등록은 다음 HPD(플러그) 사이클 때 커넥터 목록에 반영됨 -
    # 즉시 반영은 아니지만 슬롯이 영구히 낡은 채로 남는 것을 막는 목적.
    safe = get_safe_auto_candidate(candidates)
    if safe is None:
        return
    try:
        with open(MODELINE_PARAM, "w") as f:
            f.write(safe["modeline"])
        with open(DISPLAYMODE_PARAM, "w") as f:
            f.write(safe["name"])
        log(f"커스텀 슬롯 재등록(이전 모니터 잔재 제거용): {safe['name']}")
    except OSError as e:
        log(f"커스텀 슬롯 재등록 실패({e}) - 무시")


def write_edid_baseline():
    # 현재 EDID의 sha256을 기준선으로 기록 - hdmi-hotplug가 재연결 때 이
    # 값과 비교해 "다른 모니터로 교체"를 감지함. 해상도 결정이 일어나는
    # 모든 경로(S60display/S99 루프/ES 게임 복귀/terminal.py)가 cmd_apply를
    # 지나므로, 기준선은 항상 "지금 적용된 해상도가 협상된 그 모니터"를
    # 가리키는 불변식이 유지됨.
    # 주의: 해시 대상은 rawedid "파일 바이트 그대로"(hex 텍스트+개행) -
    # hdmi-hotplug의 "sha256sum rawedid"와 정확히 같은 값이 나와야 함.
    try:
        with open(RAWEDID_PATH, "rb") as f:
            digest = hashlib.sha256(f.read()).hexdigest()
        with open(EDID_BASELINE, "w") as f:
            f.write(digest + "\n")
    except Exception as e:
        log(f"EDID 기준선 기록 실패({e}) - 무시")


def cmd_apply():
    write_edid_baseline()
    requested = read_conf_value("system.hdmi_resolution", "auto")
    candidates = get_candidates()

    if requested == "auto":
        safe = get_safe_auto_candidate(candidates)
        if safe is None:
            log("안전 범위(55~61Hz) 후보 없음 - 폴백")
            print(FALLBACK_MODE)
            return
        log(f"EDID 네이티브 감지: {safe['width']}x{safe['height']}"
            f"@{safe['refresh']:.2f}Hz -> {safe['name']}")
        apply_candidate(safe)
        return

    if requested.startswith("custom_"):
        # ES 메뉴에서 --list 결과의 name(예: custom_2560x1600_60hz)을 그대로
        # conf 값으로 씀 - 여기서 그 이름과 일치하는 후보를 그대로 찾아 적용.
        # get_candidates()가 새로고침율로 걸러내지 않으므로 사용자가 직접
        # 고른 값이면 55~61Hz 밖이어도 그대로 적용됨(무인 부팅인 auto와
        # 달리 사용자가 목록 보고 명시적으로 고른 것이므로).
        match = next((c for c in candidates if c["name"] == requested), None)
        if match is None:
            log(f"요청한 모드({requested})가 지금 EDID 후보에 없음 - 폴백")
            print(FALLBACK_MODE)
            return
        log(f"수동 지정 해상도 적용: {match['width']}x{match['height']}"
            f"@{match['refresh']:.2f}Hz -> {match['name']}")
        apply_candidate(match)
        return

    if requested in FALLBACK_CUSTOM_MODES:
        # 고정 16:10 폴백 등 - EDID 조회 없이 내장된 모드라인을 바로 등록.
        log(f"고정 폴백 모드 적용: {requested}")
        apply_candidate(FALLBACK_CUSTOM_MODES[requested])
        return

    # 그 외(예: "1080p60hz") - odroid-drm-fbset이 이미 아는 CEA 모드 이름.
    # 커스텀 슬롯은 현재 모니터 기준으로 재등록(이전 모니터 잔재 제거).
    refresh_custom_slot(candidates)
    log(f"수동 지정 CEA 모드 사용: {requested}")
    print(requested)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--list":
        cmd_list()
    else:
        cmd_apply()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log(f"예외 발생({e}) - 폴백")
        print(FALLBACK_MODE)
