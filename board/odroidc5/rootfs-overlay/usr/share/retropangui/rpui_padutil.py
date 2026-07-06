"""
rpui_padutil - 연결된 패드 감지 + es_input.cfg 버튼 코드 조회 공용 모듈.

패드마다 버튼의 evdev 코드가 완전히 다르므로(예: 어떤 패드는 select가 314인데
다른 패드는 297) 하드코딩하지 않고, ES가 이미 계산해둔 es_input.cfg의 코드를
그대로 읽어서 쓴다 - 이 프로젝트 전체에서 패드 매핑에 쓰는 것과 동일한 정답
소스(2026-07-06, rpui-termkeys.py에서 분리).
"""
import xml.etree.ElementTree as ET

ES_INPUT_CFG = "/root/.emulationstation/es_input.cfg"


def detect_joysticks():
    """/proc/bus/input/devices에서 조이스틱(js*) 핸들러를 가진 장치의
    (이름, /dev/input/eventN) 목록을 반환. rpui-launcher.py의
    detect_joypad_names()와 같은 판별 방식(js 핸들러 유무)."""
    result = []
    try:
        content = open("/proc/bus/input/devices").read()
    except OSError:
        return result

    for block in content.split("\n\n"):
        name = None
        event_path = None
        has_js = False
        for line in block.splitlines():
            if line.startswith("N: Name="):
                name = line.split("=", 1)[1].strip().strip('"')
            elif line.startswith("H: Handlers="):
                handlers = line.split("=", 1)[1].split()
                if any(h.startswith("js") for h in handlers):
                    has_js = True
                for h in handlers:
                    if h.startswith("event"):
                        event_path = "/dev/input/" + h
        if name and has_js and event_path:
            result.append((name, event_path))
    return result


def find_codes_for_device(name, wanted_names):
    """es_input.cfg에서 이 장치 이름과 일치하는 joystick 항목의
    지정된 버튼 이름들의 evdev code를 dict로 반환."""
    try:
        tree = ET.parse(ES_INPUT_CFG)
    except (OSError, ET.ParseError):
        return {}

    for cfg in tree.getroot().findall("inputConfig"):
        if cfg.get("type") != "joystick" or cfg.get("deviceName") != name:
            continue
        codes = {}
        for inp in cfg.findall("input"):
            n = inp.get("name")
            if inp.get("type") == "button" and n in wanted_names:
                try:
                    codes[n] = int(inp.get("code"))
                except (TypeError, ValueError):
                    pass
        return codes
    return {}
