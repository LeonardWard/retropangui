# make_m3u_from_es_systems.py

import os
import re
import shutil
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
    파일명에서 디스크 번호(Disk/Disc/CD+숫자)만 제거하고,
    국가/버전등의 괄호 정보는 그대로 둔다.
    대괄호 [] 내용은 필요에 따라(예: No-Intro) 삭제, 괄호()는 유지.
    마지막 특수문자-공백도 정리
    """
    name = os.path.splitext(filename)[0]
    # [ ] 내부 내용 제거 (게임 데이터베이스 특성에 따라 그대로 둘 수도 있음, 예시대로 불필요시 유지)
    # name = re.sub(r'\[[^\]]*\]', '', name)
    # ( ) 괄호 내용은 삭제하지 않음!
    # 디스크, CD, Disk + 번호 패턴만 제거, 괄호 내부도 포함하여
    name = re.sub(r'\((?:\s*)?(cd|disc|disk)[\s\-]*\d+(?:\s*)?\)', '', name, flags=re.IGNORECASE)
    name = re.sub(r'(cd|disc|disk)[\s\-]*\d+', '', name, flags=re.IGNORECASE)
    # 끝부분 -, _, 공백 등 제거
    name = re.sub(r'[-_\s]+$', '', name)
    # 중복 공백 정리, 앞뒤 공백 제거
    name = re.sub(r'\s{2,}', ' ', name)
    name = name.strip()
    return name

def get_disk_number(filename):
    match = re.search(r'(cd|disc|disk)[\s\-]?(\d+)', filename, re.IGNORECASE)
    return int(match.group(2)) if match else None

def make_m3u_files_for_system(system):
    sys_path = os.path.expanduser(system['path'])
    exts = system['exts']
    if not os.path.isdir(sys_path):
        print(f"{system['name']}: 경로 없음 ({sys_path})")
        return
    # 폴더 내 모든 파일을 "게임별"로 그룹핑
    for folder in [os.path.join(sys_path, d) for d in os.listdir(sys_path) if os.path.isdir(os.path.join(sys_path, d))] + [sys_path]:
        files = [f for f in os.listdir(folder) if os.path.isfile(os.path.join(folder, f))]
        # 게임별 그룹핑: {game_key: {disk_num: {ext: filename}}}
        game_map = defaultdict(lambda: defaultdict(dict))
        for f in files:
            ext = os.path.splitext(f)[1][1:].lower()
            if ext not in exts:
                continue
            num = get_disk_number(f)
            gamekey = game_group_key(f)
            if num is not None and gamekey:
                game_map[gamekey][num][ext] = f
        # 게임별로 처리
        for gamekey, disks in game_map.items():
            if len(disks) >= 2:
                m3u_name = gamekey.strip() + ".m3u"
                m3u_path = os.path.join(folder, m3u_name)
                # 백업(.bak) 생성
                if os.path.exists(m3u_path):
                    now_str = datetime.now().strftime("%Y%m%d_%H%M%S")
                    bak_path = m3u_path + f".{now_str}.bak"
                    shutil.copy2(m3u_path, bak_path)
                    print(f"{system['name']} - 백업됨: {bak_path}")
                with open(m3u_path, "w", encoding="utf-8") as f:
                    for num in sorted(disks):
                        if 'cue' in disks[num]:
                            f.write(disks[num]['cue'] + "\n")
                        else:
                            others = [v for k, v in disks[num].items() if k != 'cue']
                            if others:
                                f.write(sorted(others)[0] + "\n")
                print(f"{system['name']} - 생성됨: {m3u_path}")

def main():
    import argparse
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
