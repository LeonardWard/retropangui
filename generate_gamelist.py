# 파일명: generate_gamelist.py

import argparse
import os
import sys
import glob
from xml.etree import ElementTree as ET
from xml.dom import minidom
from datetime import datetime

MULTI_DISC_SYSTEMS = [
    "psx", "segacd", "saturn", "dreamcast", "pcenginecd",
    "turbografxcd", "amigacd32", "3do", "pc98", "pc88"
]

def get_rom_extensions_from_es_config(es_systems_cfg_content, roms_dir):
    unique_extensions = set()
    try:
        root = ET.fromstring(es_systems_cfg_content)
        for system in root.findall('.//system'):
            path_elem = system.find('path')
            if path_elem is not None:
                system_path = os.path.abspath(os.path.expanduser(path_elem.text.strip()))
                if system_path in roms_dir or roms_dir in system_path:
                    ext_elem = system.find('extension')
                    if ext_elem is not None:
                        raw_text = "".join(ext_elem.itertext()).strip()
                        if raw_text:
                            raw_exts = raw_text.replace(';', ' ').replace(',', ' ').split()
                            for ext in raw_exts:
                                ext = ext.strip().lower()
                                if ext and not ext.startswith('files:'):
                                    if not ext.startswith('.'):
                                        ext = '.' + ext
                                    unique_extensions.add(ext)
    except ET.ParseError as e:
        print(f"es_systems.cfg 파싱 오류: {e}")
    return sorted(unique_extensions)

def scan_roms_directory(roms_dir, rom_extensions):
    found_roms = []
    for root, _, files in os.walk(roms_dir):
        for file in files:
            if any(file.lower().endswith(ext) for ext in rom_extensions):
                rom_path = os.path.join(root, file)
                found_roms.append({"path": rom_path})
    return found_roms

def parse_m3u_targets(m3u_path):
    targets = set()
    try:
        with open(m3u_path, encoding="utf-8") as f:
            for line in f:
                target = line.strip()
                if not target or target.startswith("#"):
                    continue
                base = os.path.splitext(os.path.basename(target))[0].lower()
                targets.add(base)
    except Exception:
        pass
    return targets

def filter_multi_disc_roms(roms):
    rom_paths = [r['path'] for r in roms]
    m3u_in_dir = {}
    for rom in roms:
        if rom["path"].lower().endswith(".m3u"):
            directory = os.path.dirname(rom["path"])
            m3u_in_dir.setdefault(directory, []).append(rom["path"])
    dir_m3u_targets = {}
    for directory, m3u_list in m3u_in_dir.items():
        targets = set()
        for m3u_file in m3u_list:
            targets |= parse_m3u_targets(m3u_file)
        dir_m3u_targets[directory] = targets

    filtered = []
    for rom in roms:
        path_lower = rom["path"].lower()
        directory = os.path.dirname(rom["path"])
        base = os.path.splitext(os.path.basename(rom["path"]))[0].lower()
        ext = os.path.splitext(rom["path"])[1].lower()
        if ext == ".m3u":
            filtered.append(rom)
            continue
        if directory in dir_m3u_targets:
            if base in dir_m3u_targets[directory]:
                continue
        if ext in (".cue", ".ccd", ".toc", ".mds", ".chd", ".iso"):
            filtered.append(rom)
    return filtered

def dedupe_prefer_one_descriptor(roms):
    preferred_exts = [".m3u", ".cue", ".ccd", ".toc", ".mds", ".chd", ".iso"]
    folder_games = {}
    for rom in roms:
        path = rom["path"]
        directory = os.path.dirname(path)
        basename = os.path.splitext(os.path.basename(path))[0]
        if directory not in folder_games:
            folder_games[directory] = {}
        folder_games[directory][basename] = rom

    deduped_roms = []
    for directory in folder_games:
        games_per_base = {}
        for basename, rom in folder_games[directory].items():
            ext = os.path.splitext(rom["path"])[1].lower()
            if basename not in games_per_base:
                games_per_base[basename] = {}
            games_per_base[basename][ext] = rom
        for basename in games_per_base:
            for ext in preferred_exts:
                if ext in games_per_base[basename]:
                    deduped_roms.append(games_per_base[basename][ext])
                    break
    return deduped_roms

def parse_existing_gamelist(gamelist_path):
    existing_games = {}
    if not os.path.exists(gamelist_path):
        return existing_games
    try:
        tree = ET.parse(gamelist_path)
        root = tree.getroot()
        for game_element in root.findall('./game'):
            path_element = game_element.find('path')
            if path_element is not None and path_element.text:
                rom_path = path_element.text
                game_data = {"path": rom_path}
                for child in game_element:
                    if child.tag != 'path':
                        game_data[child.tag] = child.text
                existing_games[rom_path] = game_data
    except ET.ParseError:
        print(f"경고: {gamelist_path} 파싱 실패, 기존 메타데이터를 무시합니다.")
        return {}
    return existing_games

def create_backup(file_path):
    if os.path.exists(file_path):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = f"{file_path}.bak_{timestamp}"
        os.rename(file_path, backup_path)
        print(f"백업 생성됨: {backup_path}")

def get_relative_path(rom_path, roms_dir):
    rel_path = os.path.relpath(rom_path, roms_dir)
    return "./" + rel_path.replace("\\", "/")

def generate_gamelist_xml(games_data, output_file, merge=False):
    roms_dir = os.path.dirname(output_file)
    final_games_data = {}
    if os.path.exists(output_file):
        create_backup(output_file)
    if merge and os.path.exists(output_file):
        existing_games = parse_existing_gamelist(output_file)
        final_games_data.update(existing_games)
    for new_game_data in games_data:
        rom_path = new_game_data["path"]
        if merge and rom_path in final_games_data:
            existing_entry = final_games_data[rom_path]
            existing_entry["path"] = rom_path
        else:
            final_games_data[rom_path] = new_game_data
    game_list = ET.Element("gameList")
    for rom_path in sorted(final_games_data.keys()):
        game_data = final_games_data[rom_path]
        game = ET.SubElement(game_list, "game")
        ET.SubElement(game, "path").text = get_relative_path(game_data["path"], roms_dir)
        name_text = game_data.get("name") or os.path.splitext(os.path.basename(game_data["path"]))[0]
        ET.SubElement(game, "name").text = name_text
        if game_data.get("desc"):
            ET.SubElement(game, "desc").text = game_data["desc"]
        if game_data.get("image"):
            ET.SubElement(game, "image").text = game_data["image"]
    xml_out = ET.tostring(game_list, encoding='utf-8')
    pretty_xml = minidom.parseString(xml_out).toprettyxml(indent="  ")
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(pretty_xml)
    print(f"gamelist.xml이 {output_file}에 생성되었습니다")

def ensure_es_systems_cfg(path: str) -> str:
    resolved = os.path.abspath(os.path.expanduser(path))
    if not os.path.isfile(resolved):
        print(f"오류: es_systems.cfg 파일을 찾을 수 없습니다: {resolved}")
        sys.exit(1)
    return resolved

def get_systems_from_cfg(es_systems_cfg_content):
    root = ET.fromstring(es_systems_cfg_content)
    result = []
    for system in root.findall('.//system'):
        name = system.find('name').text.strip() if system.find('name') is not None else None
        path = system.find('path').text.strip() if system.find('path') is not None else None
        extensions = system.find('extension').text.strip() if system.find('extension') is not None else None
        if name and path:
            result.append({'name': name, 'path': os.path.abspath(os.path.expanduser(path)), 'extensions': extensions})
    return result

if __name__ == "__main__":
    DEFAULT_ES_CFG_PATH = os.path.expanduser("~/.emulationstation/es_systems.cfg")

    parser = argparse.ArgumentParser(
        description="EmulationStation용 시스템별 gamelist.xml 파일 자동 생성기",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument("--system", nargs="+", default=["all"],
        help="처리할 시스템명들 (예: psx snes all). es_systems.cfg의 name 태그와 일치해야 함. 생략 또는 all이면 전체 처리.")
    parser.add_argument("--roms_dir", default=None,
        help="(선택) 직접 지정할 ROM 폴더 경로. 지정 시 --system 옵션 무시.")
    parser.add_argument("--es_systems_cfg_path", default=DEFAULT_ES_CFG_PATH, help="es_systems.cfg 파일의 경로")
    parser.add_argument("--merge", action="store_true", help="기존 gamelist.xml이 있을 경우 병합")
    args = parser.parse_args()

    # 인수 없이 실행 시 사용법 출력
    if (len(sys.argv) == 1):
        parser.print_help()
        sys.exit(0)

    es_cfg_path = ensure_es_systems_cfg(args.es_systems_cfg_path)
    with open(es_cfg_path, "r", encoding="utf-8") as f:
        es_cfg_content = f.read()

    if args.roms_dir:
        system_path = os.path.abspath(args.roms_dir)
        system_name = os.path.basename(system_path)
        extensions = get_rom_extensions_from_es_config(es_cfg_content, system_path)
        print(f"사용되는 확장자: {', '.join(extensions)}")
        found_roms = scan_roms_directory(system_path, extensions)
        if any(sys in system_name.lower() for sys in MULTI_DISC_SYSTEMS):
            found_roms = filter_multi_disc_roms(found_roms)
            found_roms = dedupe_prefer_one_descriptor(found_roms)
        if found_roms:
            output_file = os.path.join(system_path, "gamelist.xml")
            generate_gamelist_xml(found_roms, output_file, merge=args.merge)
        else:
            print("ROM 파일을 찾을 수 없습니다.")
    else:
        all_systems = get_systems_from_cfg(es_cfg_content)
        selected = args.system
        # all 또는 생략일 때 모두 처리
        if "all" in [sys.lower() for sys in selected]:
            system_targets = all_systems
        else:
            system_targets = [s for s in all_systems if s['name'].lower() in [sys.lower() for sys in selected]]
            if not system_targets:
                print(f"지정한 시스템({', '.join(selected)})을 es_systems.cfg에서 찾을 수 없습니다.")
                sys.exit(1)
        for sysinfo in system_targets:
            system_path = sysinfo['path']
            system_name = sysinfo['name']
            print(f"\n[시스템] {system_name} gamelist.xml 생성 중...")
            extensions = get_rom_extensions_from_es_config(es_cfg_content, system_path)
            print(f"  사용되는 확장자: {', '.join(extensions)}")
            found_roms = scan_roms_directory(system_path, extensions)
            if any(s in system_name.lower() for s in MULTI_DISC_SYSTEMS):
                found_roms = filter_multi_disc_roms(found_roms)
                found_roms = dedupe_prefer_one_descriptor(found_roms)
            if not found_roms:
                print("  ROM 파일이 없습니다.")
                continue
            output_file = os.path.join(system_path, "gamelist.xml")
            generate_gamelist_xml(found_roms, output_file, merge=args.merge)
