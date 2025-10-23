# make_m3u_from_es_systems.py

import os
import re
import shutil
import argparse
from datetime import datetime
from collections import defaultdict

def parse_es_systems_config(config_path):
    systems = []
    if not os.path.isfile(config_path):
        print("es_systems.cfg 파일을 찾을 수 없습니다.")
        return systems
    with open(config_path, encoding="utf-8") as f:
        content = f.read()
        sys_blocks = re.split(r'</system>', content)
        for block in sys_blocks:
            name_match = re.search(r'<name>(.*?)</name>', block)
            path_match = re.search(r'<path>(.*?)</path>', block)
            ext_match = re.search(r'<extension>(.*?)</extension>', block)
            if name_match and path_match and ext_match:
                sys_name = name_match.group(1).strip()
                sys_path = path_match.group(1).strip()
                ext_list = [e.strip().lower().lstrip('.') for e in ext_match.group(1).replace(',', ' ').split()]
                systems.append({
                    'name': sys_name,
                    'path': sys_path,
                    'exts': ext_list
                })
    return systems

def game_group_key(filename):
    """
    디스크/트랙 구분, 대괄호 레이블([SLPS-xxxxx], [CRC], [REVx] 등) 모두 제거.
    국가/버전 괄호는 남김.
    """
    name = os.path.splitext(filename)[0]
    # 대괄호 레이블 전체 제거
    name = re.sub(r'\[[^\]]*\]', '', name)
    # 디스크/트랙 패턴 제거 (아래 패턴들은 앞서 안내한 방식 유지)
    patterns_remove = [
        r'\((?:cd|disc|disk|cdda)[\s\-]*\d+\)',
        r'(cd|disc|disk|cdda)[\s\-]*\d+',
        r'\d+\s*cd$',
        r'\d+\s*disc$',
        r'\d+\s*disk$',
        r'\(track[\s\-]*\d+\)',
        r'track\s*\d+',
        r'\([A-Z]\)$',
        r'[\s\-][A-Z]$',
    ]
    for pat in patterns_remove:
        name = re.sub(pat, '', name, flags=re.IGNORECASE)
    name = re.sub(r'[-_\s]+$', '', name)
    name = re.sub(r'\s{2,}', ' ', name)
    name = name.strip()
    return name

def get_disk_id(filename):
    base = os.path.splitext(filename)[0]
    patterns = [
        r'\((?:cd|disc|disk|cdda)[\s\-]*(\d+)\)',      # (Disc 1), (CD2), (Disk3)
        r'\((?:[^\)]*disc[\s\-]*(\d+)[^\)]*)\)',       # (Disc 1) 괄호 내 버전 등 포함
        r'(?:cd|disc|disk|cdda)[\s\-]?(\d+)',           # CD1, Disc2 등 접두형
        r'(\d+)\s*cd$',                                 # 1cd, 2cd
        r'(\d+)\s*disc$',                               # 2disc
        r'(\d+)\s*disk$',                               # 3disk
        r'\(track[\s\-]*(\d+)\)',                       # (Track 01)
        r'track\s*(\d+)',                               # Track 01
        r'\(([A-Z])\)$',                                # (A), (B)
        r'[\s\-]([A-Z])$'                               # -A, _B, 공백A
    ]
    for pat in patterns:
        m = re.search(pat, base, re.IGNORECASE)
        if m:
            val = m.group(1)
            return int(val) if val.isdigit() else val
    return None

def make_m3u_files_for_system(system):
    sys_path = os.path.expanduser(system['path'])
    exts = system['exts']
    if not os.path.isdir(sys_path):
        print(f"{system['name']}: 경로 없음 ({sys_path})")
        return
    for root, dirs, files in os.walk(sys_path):
        game_map = defaultdict(lambda: defaultdict(dict))
        for f in files:
            ext = os.path.splitext(f)[1][1:].lower()
            if ext not in exts:
                continue
            disk = get_disk_id(f)
            gamekey = game_group_key(f)
            if disk is not None and gamekey:
                game_map[gamekey][disk][ext] = f
        for gamekey, disks in game_map.items():
            if len(disks) >= 2:
                m3u_name = gamekey + ".m3u"
                m3u_path = os.path.join(root, m3u_name)
                # 기존 m3u 백업 (날짜+시간)
                if os.path.exists(m3u_path):
                    now_str = datetime.now().strftime("%Y%m%d_%H%M%S")
                    bak_path = m3u_path + f".{now_str}.bak"
                    shutil.copy2(m3u_path, bak_path)
                    print(f"{system['name']} - 백업됨: {bak_path}")
                with open(m3u_path, "w", encoding="utf-8") as f:
                    for disk in sorted(disks):
                        if 'cue' in disks[disk]:
                            f.write(disks[disk]['cue'] + "\n")
                        else:
                            others = [v for k, v in disks[disk].items() if k != 'cue']
                            if others:
                                f.write(sorted(others)[0] + "\n")
                print(f"{system['name']} - 생성됨: {m3u_path}")

def main():
    parser = argparse.ArgumentParser(description="멀티디스크 게임용 m3u 자동 생성기")
    parser.add_argument("--config", type=str, default="~/.emulationstation/es_systems.cfg", help="es_systems.cfg 위치")
    parser.add_argument("--system", type=str, help="특정 시스템 이름만 처리 (예: psx)")
    args = parser.parse_args()
    config_path = os.path.expanduser(args.config)
    systems = parse_es_systems_config(config_path)
    if args.system:
        systems = [s for s in systems if s['name'].lower() == args.system.lower()]
        if not systems:
            print(f"지정한 시스템({args.system}) 정보를 찾을 수 없습니다.")
            return
    for system in systems:
        make_m3u_files_for_system(system)

if __name__ == "__main__":
    main()
