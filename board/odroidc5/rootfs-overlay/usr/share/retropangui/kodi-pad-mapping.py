#!/usr/bin/env python3
"""
kodi-pad-mapping - Kodi 실행 직전에 호출되어 조이패드 buttonmap을 심어준다.

kodi-peripheral-joystick(peripheral.joystick 애드온)는 자체 buttonmap이
없으면 조이패드 입력을 전혀 인식하지 못한다 - 그러면 사용자가 Kodi 내부
"Configure joystick" 마법사를 수동으로 돌려야 하는데, 조이패드로 그 메뉴
자체에 진입할 수 없어 사실상 조작이 막힌다.

Batocera/Recalbox(configgen/generators/kodi/kodiConfig.py)가 쓰는 것과
동일한 방식을 이식: EmulationStation이 이미 아는 GUID 기반 버튼 매핑
(es_input.cfg)을 Kodi 실행 시점마다 peripheral.joystick의 buttonmap XML로
변환해 심는다. 패드 감지는 이 프로젝트 전체가 공유하는 rpui_padutil의
정답 소스를 그대로 재사용.
"""
import fcntl
import hashlib
import os
import struct
import sys
import xml.etree.ElementTree as ET
from xml.dom import minidom

sys.path.insert(0, "/usr/share/retropangui")
from rpui_padutil import detect_joysticks  # noqa: E402

JSIOCGAXES = 0x80016A11
JSIOCGBUTTONS = 0x80016A12

ES_INPUT_CFG = "/root/.emulationstation/es_input.cfg"
ES_INPUT_USER_CFG = "/root/.emulationstation/es_input_rpui_user.cfg"
KODI_ADDON_DATA = "/root/.kodi/userdata/addon_data/peripheral.joystick"
KODI_BUTTONMAP_DIR = KODI_ADDON_DATA + "/resources/buttonmaps/xml/udev"
KODI_SETTINGS_XML = KODI_ADDON_DATA + "/settings.xml"

# es_input.cfg 원본 이름(구세대 RetroPie 별칭 포함) -> 정규화된 이름.
# 이 프로젝트의 InputConfig::isMappedLike()/GuiInputConfig.cpp 확인 결과,
# leftshoulder/pageup, lefttrigger/l2, rightshoulder/pagedown, righttrigger/r2,
# leftthumb/l3, rightthumb/r3, hotkey/hotkeyenable은 같은 물리 버튼의 별칭.
ALIAS_TO_CANON = {
    "a": "a", "b": "b", "x": "x", "y": "y",
    "up": "up", "down": "down", "left": "left", "right": "right",
    "start": "start", "select": "select",
    "hotkey": "hotkey", "hotkeyenable": "hotkey",
    "leftshoulder": "leftshoulder", "pageup": "leftshoulder",
    "rightshoulder": "rightshoulder", "pagedown": "rightshoulder",
    "lefttrigger": "lefttrigger", "l2": "lefttrigger",
    "righttrigger": "righttrigger", "r2": "righttrigger",
    "leftthumb": "leftthumb", "l3": "leftthumb",
    "rightthumb": "rightthumb", "r3": "rightthumb",
    "joystick1up": "stick1up", "leftanalogup": "stick1up",
    "joystick1left": "stick1left", "leftanalogleft": "stick1left",
    "joystick2up": "stick2up", "rightanalogup": "stick2up",
    "joystick2left": "stick2left", "rightanalogleft": "stick2left",
}

# 정규화된 이름 -> Kodi game.controller.default 표준 액션 이름.
# a/b, x/y는 위치 기준 스왑: 이 프로젝트의 "a"=EAST/"b"=SOUTH(닌텐도 배치,
# GuiInputConfig.cpp dispName 확인)인데 Kodi 표준은 Xbox 방향 기준
# (a=south, b=east) 이라 위치가 같은 버튼끼리 이어주려면 이름이 바뀐다.
CANON_TO_KODI = {
    "a": "b", "b": "a", "x": "y", "y": "x",
    "start": "start", "select": "back", "hotkey": "guide",
    "leftshoulder": "leftbumper", "rightshoulder": "rightbumper",
    "lefttrigger": "lefttrigger", "righttrigger": "righttrigger",
    "leftthumb": "leftthumb", "rightthumb": "rightthumb",
    "up": "up", "down": "down", "left": "left", "right": "right",
}

# 정규화된 스틱 이름 -> (Kodi feature 이름, 저장된 축의 방향, 반대 방향)
STICK_INFO = {
    "stick1up":   ("leftstick", "up", "down"),
    "stick1left": ("leftstick", "left", "right"),
    "stick2up":   ("rightstick", "up", "down"),
    "stick2left": ("rightstick", "left", "right"),
}

# SDL_HAT_* 비트값 -> 방향 이름 (es_input.cfg의 hat value와 동일 규약)
HAT_POS = {1: "up", 2: "right", 4: "down", 8: "left"}


def parse_configs():
    """deviceName -> inputConfig 엘리먼트. 사용자 파일이 있으면 시스템
    기본값을 덮어써서 우선순위를 준다(InputManager::loadInputConfig와 동일)."""
    configs = {}
    for path in (ES_INPUT_CFG, ES_INPUT_USER_CFG):
        if not os.path.isfile(path):
            continue
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError:
            continue
        for cfg in root.findall("inputConfig"):
            if cfg.get("type") != "joystick":
                continue
            name = cfg.get("deviceName")
            if name:
                configs[name] = cfg
    return configs


def vidpid(guid):
    """SDL GUID(리눅스 포맷) 문자열에서 vid/pid 16진 문자열을 뽑는다.
    Batocera의 vidpid() 공식과 동일한 바이트 오프셋."""
    return guid[10:12] + guid[8:10], guid[18:20] + guid[16:18]


def find_js_path(device_name):
    """es_input.cfg의 deviceName과 같은 이름을 가진 /dev/input/jsN 경로를 찾는다.
    rpui_padutil.detect_joysticks()는 eventN만 주므로 여기서 별도로 파싱."""
    try:
        content = open("/proc/bus/input/devices").read()
    except OSError:
        return None
    for block in content.split("\n\n"):
        name = None
        js_path = None
        for line in block.splitlines():
            if line.startswith("N: Name="):
                name = line.split("=", 1)[1].strip().strip('"')
            elif line.startswith("H: Handlers="):
                for h in line.split("=", 1)[1].split():
                    if h.startswith("js"):
                        js_path = "/dev/input/" + h
        if name == device_name and js_path:
            return js_path
    return None


def query_real_counts(js_path):
    """joystick.h ioctl로 실제 축/버튼 개수를 조회한다 - peripheral.joystick의
    udev provider가 보는 것과 동일한 값. es_input.cfg의 deviceNbAxes/
    deviceNbButtons는 ES가 SDL로 잰 값이라 트리거를 버튼/축 어느 쪽으로
    셀지 등에서 raw joystick API(udev가 실제로 쓰는 것)와 어긋날 수 있다
    (실기기에서 Xbox 360 패드로 실측: es_input.cfg는 13버튼/6축인데 실제
    ioctl은 11버튼/8축 - 이 불일치 때문에 Kodi의 엄격한 device 매칭이
    실패해 buttonmap이 전혀 안 먹혔음, 2026-07-21)."""
    try:
        fd = os.open(js_path, os.O_RDONLY | os.O_NONBLOCK)
    except OSError:
        return None
    try:
        axes = struct.unpack("B", fcntl.ioctl(fd, JSIOCGAXES, b"\x00"))[0]
        buttons = struct.unpack("B", fcntl.ioctl(fd, JSIOCGBUTTONS, b"\x00"))[0]
        return axes, buttons
    except OSError:
        return None
    finally:
        os.close(fd)


def add_stick_axis(stick_features, controller, stick_name, primary_dir, secondary_dir, axis_id, value):
    feature = stick_features.get(stick_name)
    if feature is None:
        feature = ET.SubElement(controller, "feature")
        feature.set("name", stick_name)
        stick_features[stick_name] = feature

    v = int(value)
    primary_sign = "-" if v < 0 else "+"
    secondary_sign = "+" if v < 0 else "-"
    ET.SubElement(feature, primary_dir).set("axis", f"{primary_sign}{axis_id}")
    ET.SubElement(feature, secondary_dir).set("axis", f"{secondary_sign}{axis_id}")


def build_buttonmap(cfg, name, real_counts=None):
    guid = cfg.get("deviceGUID", "")
    if len(guid) < 20:
        return None
    vid, pid = vidpid(guid)
    try:
        hat_count = int(cfg.get("deviceNbHats", "0"))
    except ValueError:
        hat_count = 0

    if real_counts is not None:
        # ioctl 실측값 사용 (하단 query_real_counts 설명 참고) - 이 축 개수는
        # 이미 hat이 가상축 2개로 포함된 최종값이므로, hat 가상축 인덱스
        # 계산에 쓸 "hat 이전 실축 개수"는 여기서 hat 몫을 다시 빼야 한다.
        total_axis, button_count = real_counts
        axis_count = total_axis - 2 * hat_count
    else:
        try:
            axis_count = int(cfg.get("deviceNbAxes", "0"))
        except ValueError:
            axis_count = 0
        button_count = cfg.get("deviceNbButtons", "0")
        total_axis = axis_count + 2 * hat_count

    buttonmap = ET.Element("buttonmap")
    device = ET.SubElement(buttonmap, "device")
    device.set("name", name)
    device.set("provider", "udev")
    device.set("vid", vid)
    device.set("pid", pid)
    device.set("buttoncount", str(button_count))
    device.set("axiscount", str(total_axis))

    controller = ET.SubElement(device, "controller")
    controller.set("id", "game.controller.default")

    seen = set()
    stick_features = {}

    for inp in cfg.findall("input"):
        raw_name = inp.get("name")
        canon = ALIAS_TO_CANON.get(raw_name)
        if canon is None or canon in seen:
            continue

        itype = inp.get("type")
        value = inp.get("value", "0")
        iid = inp.get("id", "0")

        if canon in STICK_INFO:
            seen.add(canon)
            stick_name, primary_dir, secondary_dir = STICK_INFO[canon]
            add_stick_axis(stick_features, controller, stick_name, primary_dir, secondary_dir, iid, value)
            continue

        kodi_name = CANON_TO_KODI.get(canon)
        if kodi_name is None:
            continue
        seen.add(canon)

        if itype == "button":
            feature = ET.SubElement(controller, "feature")
            feature.set("name", kodi_name)
            feature.set("button", str(int(iid)))
        elif itype == "hat":
            try:
                hat_pos = HAT_POS.get(int(value))
            except ValueError:
                hat_pos = None
            if hat_pos is None:
                continue
            feature = ET.SubElement(controller, "feature")
            feature.set("name", kodi_name)
            axis_num = axis_count if hat_pos in ("left", "right") else axis_count + 1
            sign = "+" if hat_pos in ("down", "right") else "-"
            feature.set("axis", f"{sign}{axis_num}")
        elif itype == "axis":
            feature = ET.SubElement(controller, "feature")
            feature.set("name", kodi_name)
            try:
                sign = "+" if int(value) >= 0 else "-"
            except ValueError:
                sign = "+"
            feature.set("axis", f"{sign}{iid}")

    return buttonmap


def write_xml(elem, out_path):
    rough = ET.tostring(elem, encoding="unicode")
    pretty = minidom.parseString(rough).toprettyxml(indent="  ")
    with open(out_path, "w") as f:
        f.write(pretty)


def force_udev_provider():
    os.makedirs(KODI_ADDON_DATA, exist_ok=True)
    with open(KODI_SETTINGS_XML, "w") as f:
        f.write('<settings version="2"><setting id="driver_linux">1</setting></settings>')


def main():
    joysticks = detect_joysticks()
    if not joysticks:
        # 패드가 없으면 이전에 만들어둔 buttonmap을 지우지 않는다(재부팅 없이
        # 마지막에 쓰던 패드를 다시 꽂는 경우를 위해 - Batocera와 동일 정책).
        return

    configs = parse_configs()
    os.makedirs(KODI_BUTTONMAP_DIR, exist_ok=True)

    done = set()
    for name, _event_path in joysticks:
        if name in done:
            continue
        done.add(name)

        cfg = configs.get(name)
        if cfg is None:
            # es_input.cfg DB에 없는 패드는 매핑 정보가 없어 건너뜀 -
            # ES 마법사로 직접 잡아야 하는 건 기존 프로젝트 관례와 동일.
            continue

        js_path = find_js_path(name)
        real_counts = query_real_counts(js_path) if js_path else None

        buttonmap = build_buttonmap(cfg, name, real_counts)
        if buttonmap is None:
            continue

        digest = hashlib.md5(name.encode("utf-8")).hexdigest()[:8]
        guid = cfg.get("deviceGUID", "")
        out_path = os.path.join(KODI_BUTTONMAP_DIR, f"rpui_{guid}_{digest}.xml")
        write_xml(buttonmap, out_path)

    force_udev_provider()


if __name__ == "__main__":
    main()
