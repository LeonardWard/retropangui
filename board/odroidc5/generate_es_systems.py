#!/usr/bin/env python3
"""
generate_es_systems.py - systems.json으로부터 es_systems.xml 생성

Usage:
    python3 generate_es_systems.py \
        --systems  board/odroidc5/systems.json \
        --output   TARGET_DIR/etc/emulationstation/es_systems.xml \
        --roms-path    /share/roms \
        --retroarch    /opt/retropangui/bin/retroarch \
        --config       /opt/retropangui/retroarch.cfg
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

        lines.append('')
        lines.append('  <system>')
        lines.append(f'    <name>{name}</name>')
        lines.append(f'    <fullname>{fullname}</fullname>')
        lines.append(f'    <path>{roms_path}/{name}</path>')
        lines.append(f'    <extension>{extensions}</extension>')
        lines.append('    <cores>')
        for c in cores:
            lines.append(
                f'      <core name="{c["name"]}" fullname="{c["fullname"]}"'
                f' module_id="{c["module_id"]}" priority="{c["priority"]}"'
                f' extensions="{extensions}"/>'
            )
        lines.append('    </cores>')
        lines.append(
            f'    <command>{retroarch} -L %CORE% --config {config} %ROM%</command>'
        )
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
    parser.add_argument('--retroarch',    default='/opt/retropangui/bin/retroarch')
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
