#!/usr/bin/env python3

import os
import sys
import shutil
from pathlib import Path


PRIORITIES_CONF = "/etc/retropangui/priorities.conf"
RETROARCH_BIN   = "/usr/bin/retroarch"
ETC_RA_CFG      = "/etc/retroarch.cfg"


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
