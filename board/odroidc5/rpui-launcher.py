#!/usr/bin/env python3

import os
import sys
import shutil
from pathlib import Path


PRIORITIES_CONF = "/etc/retropangui/priorities.conf"
RETROARCH_BIN   = "/usr/bin/retroarch"
ETC_RA_CFG      = "/etc/retroarch.cfg"
AUTOCONFIG_DIR  = "/etc/retroarch/autoconfig"
HOTKEY_OVERRIDE_CFG = "/tmp/retropangui-hotkey-override.retroarch.cfg"


def log(msg):
    print(f"[launcher] {msg}", file=sys.stderr)


def resolve_core_from_priorities(system):
    """priorities.conf에서 system의 priority=1 module_id 반환."""
    try:
        with open(PRIORITIES_CONF) as f:
            best = None
            best_prio = 9999
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split(":")
                if len(parts) < 3:
                    continue
                module_id, sys_name, priority = parts[0], parts[1], parts[2]
                if sys_name == system:
                    try:
                        p = int(priority)
                        if p < best_prio:
                            best_prio = p
                            best = module_id
                    except ValueError:
                        pass
            return best
    except OSError as e:
        log(f"Warning: priorities.conf 읽기 실패 — {e}")
        return None


def module_id_to_so_name(module_id):
    """lr-pcsx-rearmed → pcsx_rearmed_libretro.so"""
    name = module_id
    if name.startswith("lr-"):
        name = name[3:]
    name = name.replace("-", "_")
    return f"{name}_libretro.so"


def resolve_core_path(module_id, cores_path):
    """module_id → 실제 .so 경로."""
    core_dir = Path(cores_path) / module_id
    installed = core_dir / ".installed_so_name"
    if installed.exists():
        so_name = installed.read_text().strip().splitlines()[0]
    else:
        so_name = module_id_to_so_name(module_id)
    core_so = core_dir / so_name
    if not core_so.exists():
        log(f"Warning: 코어 .so 없음: {core_so}")
    return str(core_so)


def detect_joypad_names():
    """/proc/bus/input/devices에서 joydev(js*) 핸들러를 가진 장치 이름 목록 반환.
    (키보드/마우스 등은 js 핸들러가 없어서 자동 제외됨)"""
    names = []
    try:
        content = Path("/proc/bus/input/devices").read_text()
    except OSError:
        return names

    for block in content.split("\n\n"):
        name = None
        has_js = False
        for line in block.splitlines():
            if line.startswith("N: Name="):
                name = line.split("=", 1)[1].strip().strip('"')
            elif line.startswith("H: Handlers="):
                if any(tok.startswith("js") for tok in line.split("=", 1)[1].split()):
                    has_js = True
        if name and has_js:
            names.append(name)
    return names


# autoconfig의 필드명 -> 오버라이드할 전역 retroarch.cfg 필드명.
# a/b/x/y는 RA 필드 이름 자체가 물리 위치를 고정 표현함(b=South, a=East,
# y=West, x=North — 8BitDo/PS2 어댑터 작업에서 이미 확인된 이 프로젝트
# 전역 관례). 물리 위치 기준 핫키 조합(2026-07-05 사용자 확인):
#   메뉴 부르기=South(b) 저장=West(y) 로드=North(x) 초기화=East(a)
_PAD_FIELD_TO_GLOBAL_OVERRIDE = {
    "input_menu_toggle_btn": "input_enable_hotkey_btn",  # 핫키 활성화 버튼(홈/가이드 또는 Select)
    "input_start_btn":       "input_exit_emulator_btn",
    "input_b_btn":           "input_menu_toggle_btn",     # 이건 전역 쪽 필드 — RA 메뉴 열기 액션
    "input_a_btn":           "input_reset_btn",
    "input_y_btn":           "input_save_state_btn",
    "input_x_btn":           "input_load_state_btn",
}


def find_pad_keys_for_device(name):
    """/etc/retroarch/autoconfig/*.cfg 중 이 장치 이름(또는 alt 이름)과 일치하는
    파일을 찾아 _PAD_FIELD_TO_GLOBAL_OVERRIDE에 정의된 필드들의 값을 dict로 반환.

    RetroArch의 input_enable_hotkey_btn/input_exit_emulator_btn/input_reset_btn/
    input_save_state_btn/input_load_state_btn/input_menu_toggle_btn(전역)은 전부
    전역 설정이라 조이패드별 autoconfig 안에 적어도 무시됨(2026-07-05, 8BitDo
    SN30 Pro/PS2 Twin USB 어댑터 실기기 확인 — 이 버튼들의 논리 인덱스가
    패드마다 다른데 전역값은 Xbox 360 무선 수신기 기준으로 고정돼 있어서
    다른 패드에서는 엉뚱한 버튼이 핫키/종료/리셋/세이브/로드로 걸림 — 예:
    PS2 Twin USB 어댑터에서 저장=Square가 아니라 Cross, 초기화=Circle이
    아니라 다른 버튼이 걸리는 등 "핫키 매핑이 엉망"으로 나타남). 그래서 매
    실행마다 현재 연결된 패드에 맞는 값을 여기서 직접 계산해 appendconfig로
    주입한다."""
    try:
        entries = os.listdir(AUTOCONFIG_DIR)
    except OSError:
        return {}

    for fname in entries:
        path = Path(AUTOCONFIG_DIR) / fname
        try:
            text = path.read_text()
        except OSError:
            continue

        device_match = False
        found = {}
        for line in text.splitlines():
            line = line.strip()
            if "=" not in line:
                continue
            key, _, val = line.partition("=")
            key = key.strip()
            val = val.strip().strip('"')
            if key == "input_device" or (key.startswith("input_device_alt") and not key.endswith("_display_name")):
                if val == name:
                    device_match = True
            elif key in _PAD_FIELD_TO_GLOBAL_OVERRIDE:
                found[key] = val

        if device_match and found:
            return found
    return {}


def write_hotkey_override():
    """연결된 패드 중 autoconfig에 핫키 관련 필드가 있는 첫 번째 것을 찾아
    input_enable_hotkey_btn/input_exit_emulator_btn/input_menu_toggle_btn/
    input_reset_btn/input_save_state_btn/input_load_state_btn 오버라이드
    파일을 써서 경로를 반환. 없으면 None."""
    for jp_name in detect_joypad_names():
        found = find_pad_keys_for_device(jp_name)
        if not found:
            continue
        lines = [
            f'{_PAD_FIELD_TO_GLOBAL_OVERRIDE[pad_key]} = "{val}"\n'
            for pad_key, val in found.items()
        ]
        try:
            Path(HOTKEY_OVERRIDE_CFG).write_text("".join(lines))
        except OSError as e:
            log(f"Warning: 핫키 오버라이드 파일 작성 실패 — {e}")
            return None
        overrides_str = ", ".join(f"{_PAD_FIELD_TO_GLOBAL_OVERRIDE[k]}={v}" for k, v in found.items())
        log(f"핫키 오버라이드: '{jp_name}' → {overrides_str}")
        return HOTKEY_OVERRIDE_CFG
    return None


def build_appendconfig_chain(rom_path, roms_root):
    """
    romsRoot/sys/ 에서 rom dir 까지 내려가며 .retroarch.cfg 수집.
    순서: /etc/retroarch.cfg → roms/sys/.retroarch.cfg → ... → rom_dir/.retroarch.cfg → rom.bin.retroarch.cfg
    """
    rom = Path(rom_path)
    roms_root = Path(roms_root)
    chain = []

    # rom 경로에서 roms_root 사이의 디렉토리 목록 (roms_root 제외, 위→아래 순서)
    dirs = []
    current = rom.parent
    while True:
        if current == roms_root or not str(current).startswith(str(roms_root)):
            break
        dirs.append(current)
        if current.parent == roms_root:
            break
        current = current.parent
    dirs.reverse()  # roms_root/sys → ... → rom.parent 순서

    for d in dirs:
        cfg = d / ".retroarch.cfg"
        if cfg.exists():
            chain.append(str(cfg))

    # 게임별 오버라이드: /path/to/game.bin.retroarch.cfg
    game_cfg = Path(str(rom) + ".retroarch.cfg")
    if game_cfg.exists():
        chain.append(str(game_cfg))

    # /etc/retroarch.cfg 를 맨 앞에 삽입
    if Path(ETC_RA_CFG).exists():
        chain.insert(0, ETC_RA_CFG)

    # 패드별 핫키 버튼 오버라이드 — /etc/retroarch.cfg(전역 기본값) 바로 뒤,
    # 시스템/게임별 커스텀 설정보다는 앞에 두어서 게임별 설정이 필요하면
    # 여전히 우선하도록 함
    hotkey_override = write_hotkey_override()
    if hotkey_override:
        insert_at = 1 if (chain and chain[0] == ETC_RA_CFG) else 0
        chain.insert(insert_at, hotkey_override)

    return "|".join(chain)


def main():
    if len(sys.argv) < 5:
        print(
            "Usage: rpui-launcher <system> <rom> <emulator> <core>",
            file=sys.stderr,
        )
        sys.exit(1)

    system   = sys.argv[1]
    rom      = sys.argv[2]
    emulator = sys.argv[3]  # 현재 미사용, 미래 확장용 (standalone 에뮬레이터 지원)
    core_arg = sys.argv[4]

    cores_path  = os.getenv("LIBRETRO_CORES_PATH", "/usr/lib/libretro")
    share_root  = os.getenv("RETROPANGUI_SHARE",   "/retropangui/share")
    roms_root   = os.path.join(share_root, "roms")

    log(f"system={system} rom={rom} emulator={emulator} core={core_arg}")

    # 1. module_id 결정
    if core_arg in ("", "default"):
        module_id = resolve_core_from_priorities(system)
        if not module_id:
            # 최후 폴백: system 이름으로 추론
            module_id = f"lr-{system}"
            log(f"Warning: priorities.conf에서 코어를 찾지 못함. 폴백: {module_id}")
        else:
            log(f"priorities.conf → module_id: {module_id}")
    else:
        module_id = core_arg
        log(f"module_id: {module_id}")

    # 2. 코어 .so 경로 결정
    core_path = resolve_core_path(module_id, cores_path)
    log(f"core path: {core_path}")

    # 3. appendconfig 체인 조립
    append_chain = build_appendconfig_chain(rom, roms_root)
    if append_chain:
        log(f"appendconfig: {append_chain}")
    else:
        log("appendconfig 체인 없음")

    # 4. retroarch argv 조립
    ra = RETROARCH_BIN
    if not Path(ra).exists():
        ra = shutil.which("retroarch") or RETROARCH_BIN

    argv = [ra, "-L", core_path]
    if append_chain:
        argv += ["--appendconfig", append_chain]
    argv.append(rom)

    log(f"exec: {' '.join(argv)}")

    # 5. 프로세스 교체
    try:
        os.execvp(ra, argv)
    except OSError as e:
        log(f"Error: execvp 실패 — {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
