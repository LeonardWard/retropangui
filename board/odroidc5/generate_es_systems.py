#!/usr/bin/env python3
"""
generate_es_systems.py - systems.json으로부터 es_systems.xml 생성

Usage:
    python3 generate_es_systems.py \
        --systems  board/odroidc5/systems.json \
        --output   TARGET_DIR/etc/emulationstation/es_systems.xml \
        --roms-path    /share/roms \
        --retroarch    /usr/bin/retroarch \
        --config       /etc/retroarch.cfg
"""

import argparse
import json
import os
import sys


def generate(systems, roms_path, retroarch, config):
    lines = ['<?xml version="1.0"?>', '<systemList>']

    for s in systems:
        name       = s['name']
        fullname   = s['fullname']
        extensions = s['extensions']
        platform   = s['platform']
        theme      = s['theme']
        cores      = s['cores']
        command_override = s.get('command')

        lines.append('')
        lines.append('  <system>')
        lines.append(f'    <name>{name}</name>')
        lines.append(f'    <fullname>{fullname}</fullname>')
        # 대부분은 roms_path/name 이지만, 일부(예: screenshots)는 롬 폴더가 아닌
        # 다른 경로를 직접 스캔해야 해서 systems.json에 "path"를 명시하면 그걸 씀
        path = s.get('path', f'{roms_path}/{name}')
        lines.append(f'    <path>{path}</path>')
        lines.append(f'    <extension>{extensions}</extension>')
        if cores:
            lines.append('    <cores>')
            for c in cores:
                lines.append(
                    f'      <core name="{c["name"]}" fullname="{c["fullname"]}"'
                    f' module_id="{c["module_id"]}" priority="{c["priority"]}"'
                    f' extensions="{extensions}"/>'
                )
            lines.append('    </cores>')
            lines.append(
                '    <command>/usr/bin/rpui-launcher %SYSTEM% %ROM% default %CORE%</command>'
            )
        elif command_override:
            # cores 없이 %ROM%을 그대로 실행하는 게 안 맞는 시스템(예: screenshots -
            # 이미지 파일을 실행 파일처럼 exec할 수 없음)은 systems.json에 "command"를
            # 직접 명시해서 전용 뷰어/스크립트를 거치게 함(2026-07-06).
            lines.append(f'    <command>{command_override}</command>')
        else:
            # cores가 없는 시스템(예: utility) — RetroArch를 거치지 않고
            # 롬(실행 스크립트)을 그대로 실행. 2026-07-05, AI CLI 등
            # 터미널 유틸리티를 게임처럼 실행하기 위한 용도.
            lines.append('    <command>%ROM%</command>')
        lines.append(f'    <platform>{platform}</platform>')
        lines.append(f'    <theme>{theme}</theme>')
        lines.append('  </system>')

    lines.append('')
    lines.append('</systemList>')
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--systems',      required=True)
    parser.add_argument('--output',       required=True)
    parser.add_argument('--roms-path',    default='/share/roms')
    parser.add_argument('--retroarch',    default='/usr/bin/retroarch')
    parser.add_argument('--config',       default='/share/system/retroarch/retroarch.cfg')
    args = parser.parse_args()

    with open(args.systems, 'r') as f:
        systems = json.load(f)

    xml = generate(systems, args.roms_path, args.retroarch, args.config)

    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    with open(args.output, 'w') as f:
        f.write(xml)

    print(f'>>> es_systems.xml 생성 완료: {args.output} ({len(systems)}개 시스템)')


if __name__ == '__main__':
    main()
