#!/usr/bin/env python3
# sync-ra-autoconfig.py - ES 사용자 매핑(es_input_rpui_user.cfg) -> RetroArch
# autoconfig 변환 (ES↔RA 입력 매핑 연동 2단계, 2026-07-20)
#
# ES가 controls-changed 이벤트를 쏠 때마다(마법사로 매핑 저장 직후) 실행됨.
# 목적: ES 마법사에서 잡은 전체 버튼 배치가 게임(RetroArch) 안에서도 그대로
# 동작하게 함 - 1단계(핫키 계열, rpui-launcher.py)와 달리 이건 패드별 전체
# 배치라 RA의 정식 autoconfig 메커니즘(장치 이름 기준 자동 인식)을 통해서만
# 정확히 동작함(input_player1_*_btn 전역 오버라이드는 멀티패드에서 깨짐).
#
# 파일 충돌 방지: 같은 장치를 가리키는 기존 autoconfig(번들 기본값 포함)가
# 있으면 그 파일명을 그대로 재사용해서 덮어씀 - 파일명이 달라지면 RA가 같은
# 장치에 매칭되는 파일 2개를 동시에 보게 돼서 어느 쪽이 이기는지 불명확해짐.
# 이 스크립트가 만든 파일은 ota-reset-on-major.list에 넣지 않음(넣으면 번들
# 파일과 이름이 겹칠 때 사용자 매핑이 메이저 업데이트마다 삭제되는, 정확히
# es_input.cfg에서 이미 겪은 버그가 재발함) - S95retropangui는 "없을 때만
# 복사"라 이 파일들을 건드리지 않음.

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ES_INPUT_USER_CFG = "/retropangui/share/system/emulationstation/es_input_rpui_user.cfg"
RA_AUTOCONFIG_DIR = "/retropangui/share/system/retroarch/autoconfig"

# ES input name -> RA 단순 버튼 필드(값은 그대로 id 사용)
_SIMPLE_BTN = {
    "a": "a", "b": "b", "x": "x", "y": "y",
    "start": "start", "select": "select",
    "leftshoulder": "l", "rightshoulder": "r",
    "leftthumb": "l3", "rightthumb": "r3",
}

# ES 방향 입력(십자키) -> RA 필드 접미사. type이 hat이면 "h{id}{dir}",
# button이면 id 그대로.
_DPAD = {"up": "up", "down": "down", "left": "left", "right": "right"}

# ES 트리거(축 또는 버튼 모두 가능) -> RA 필드 베이스
_TRIGGER = {"lefttrigger": "l2", "righttrigger": "r2"}

# ES 아날로그 스틱 방향 -> RA (축 베이스, 부호는 ES value 그대로 사용)
# 근거: RA autoconfig 실측(Sony DualShock 4 Controller.cfg) -
# l_x_plus=Right, l_x_minus=Left, l_y_plus=Down, l_y_minus=Up
_ANALOG = {
    "leftanalogright": "l_x_plus", "leftanalogleft": "l_x_minus",
    "leftanalogdown": "l_y_plus", "leftanalogup": "l_y_minus",
    "rightanalogright": "r_x_plus", "rightanalogleft": "r_x_minus",
    "rightanalogdown": "r_y_plus", "rightanalogup": "r_y_minus",
}


def sanitize_filename(name):
    keep = "".join(c if (c.isalnum() or c in " -_") else "_" for c in name)
    return keep.strip() or "unknown-device"


def find_existing_autoconfig_filename(ra_dir, device_name):
    """이미 이 장치 이름과 일치하는 autoconfig 파일이 있으면 그 파일명을 반환
    (번들 기본값 포함) - 없으면 None."""
    if not ra_dir.is_dir():
        return None
    for f in ra_dir.glob("*.cfg"):
        try:
            text = f.read_text(errors="ignore")
        except OSError:
            continue
        for line in text.splitlines():
            line = line.strip()
            if not line.startswith("input_device") or "_display_name" in line or "_id" in line.split("=")[0]:
                continue
            key, _, val = line.partition("=")
            if not key.strip().startswith(("input_device", "input_device_alt")):
                continue
            if val.strip().strip('"') == device_name:
                return f.name
    return None


def build_ra_fields(input_config_node):
    """<inputConfig> 노드의 <input> 자식들을 RA autoconfig 필드 dict로 변환."""
    fields = {}
    for inp in input_config_node.findall("input"):
        name = (inp.get("name") or "").lower()
        itype = inp.get("type") or ""
        input_id = inp.get("id")
        value = inp.get("value") or "1"
        if input_id is None:
            continue

        if name in _SIMPLE_BTN and itype == "button":
            fields[f"input_{_SIMPLE_BTN[name]}_btn"] = input_id

        elif name in _DPAD:
            dpad_dir = _DPAD[name]
            if itype == "hat":
                fields[f"input_{dpad_dir}_btn"] = f"h{input_id}{dpad_dir}"
            elif itype == "button":
                fields[f"input_{dpad_dir}_btn"] = input_id

        elif name in _TRIGGER:
            base = _TRIGGER[name]
            if itype == "axis":
                sign = "+" if not value.startswith("-") else "-"
                fields[f"input_{base}_axis"] = f"{sign}{input_id}"
            elif itype == "button":
                fields[f"input_{base}_btn"] = input_id

        elif name in _ANALOG and itype == "axis":
            sign = "+" if not value.startswith("-") else "-"
            fields[f"input_{_ANALOG[name]}_axis"] = f"{sign}{input_id}"

        # hotkeyenable 등 나머지는 1단계(rpui-launcher.py)가 이미 처리 - 여기선 무시

    return fields


def write_autoconfig(path, device_name, vendor_id, product_id, fields):
    lines = [
        'input_driver = "udev"',
        f'input_device = "{device_name}"',
    ]
    if vendor_id:
        lines.append(f'input_vendor_id = "{vendor_id}"')
    if product_id:
        lines.append(f'input_product_id = "{product_id}"')
    for key, val in fields.items():
        lines.append(f'{key} = "{val}"')
    path.write_text("\n".join(lines) + "\n")


def main():
    user_cfg = Path(ES_INPUT_USER_CFG)
    if not user_cfg.is_file():
        return 0

    try:
        root = ET.parse(user_cfg).getroot()
    except ET.ParseError:
        return 0

    ra_dir = Path(RA_AUTOCONFIG_DIR)
    ra_dir.mkdir(parents=True, exist_ok=True)

    for cfgnode in root.findall("inputConfig"):
        if cfgnode.get("type") != "joystick":
            continue
        device_name = cfgnode.get("deviceName")
        if not device_name:
            continue
        vendor_id = cfgnode.get("vendorId")
        product_id = cfgnode.get("productId")

        fields = build_ra_fields(cfgnode)
        if not fields:
            continue

        existing_name = find_existing_autoconfig_filename(ra_dir, device_name)
        filename = existing_name or (sanitize_filename(device_name) + ".cfg")
        write_autoconfig(ra_dir / filename, device_name, vendor_id, product_id, fields)

    return 0


if __name__ == "__main__":
    sys.exit(main())
