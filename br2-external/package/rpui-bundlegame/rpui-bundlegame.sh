#!/bin/sh
# rpui-bundlegame - 번들 ROM 관리
#
#   init  : 이미지 내 번들 ROM → share/roms/{sys}/ 심볼릭 링크 생성 (S61share sentinel에서 1회 호출)
#   hide  : 번들 게임 gamelist.xml hidden 처리 + ES 재시작
#   show  : 번들 게임 gamelist.xml hidden 해제 + ES 재시작
#   status: 현재 번들 게임 표시 여부 출력

SHARE="/retropangui/share"
BUNDLED="/usr/share/retropangui/bundled-roms"
SYSTEMS="nes snes psx"

cmd_init() {
    for sys in ${SYSTEMS}; do
        src="${BUNDLED}/${sys}"
        dst="${SHARE}/roms/${sys}"
        [ -d "${src}" ] || continue
        [ -d "${dst}" ] || continue
        for f in "${src}"/*; do
            [ -f "${f}" ] || continue
            ln -sf "${f}" "${dst}/" 2>/dev/null || true
        done
    done
}

_bundled_paths() {
    for sys in ${SYSTEMS}; do
        dst="${SHARE}/roms/${sys}"
        [ -d "${dst}" ] || continue
        find "${dst}" -maxdepth 1 -type l 2>/dev/null
    done
}

_gamelist_set_hidden() {
    local gamelist="$1"
    local relpath="$2"
    local hidden="$3"

    [ -f "${gamelist}" ] || printf '<?xml version="1.0"?>\n<gameList>\n</gameList>\n' > "${gamelist}"

    python3 - "${gamelist}" "${relpath}" "${hidden}" <<'EOF'
import sys, xml.etree.ElementTree as ET

gamelist, relpath, hidden = sys.argv[1], sys.argv[2], sys.argv[3]
tree = ET.parse(gamelist)
root = tree.getroot()

game = None
for g in root.findall('game'):
    p = g.find('path')
    if p is not None and p.text == relpath:
        game = g
        break

if game is None:
    game = ET.SubElement(root, 'game')
    path_el = ET.SubElement(game, 'path')
    path_el.text = relpath

h = game.find('hidden')
if h is None:
    h = ET.SubElement(game, 'hidden')
h.text = hidden

ET.indent(tree, space='  ')
tree.write(gamelist, encoding='unicode', xml_declaration=True)
EOF
}

cmd_hide() {
    for sys in ${SYSTEMS}; do
        dst="${SHARE}/roms/${sys}"
        gamelist="${dst}/gamelist.xml"
        [ -d "${dst}" ] || continue
        for link in $(find "${dst}" -maxdepth 1 -type l 2>/dev/null); do
            fname=$(basename "${link}")
            _gamelist_set_hidden "${gamelist}" "./${fname}" "true"
        done
    done
    killall emulationstation 2>/dev/null || true
}

cmd_show() {
    for sys in ${SYSTEMS}; do
        dst="${SHARE}/roms/${sys}"
        gamelist="${dst}/gamelist.xml"
        [ -f "${gamelist}" ] || continue
        for link in $(find "${dst}" -maxdepth 1 -type l 2>/dev/null); do
            fname=$(basename "${link}")
            _gamelist_set_hidden "${gamelist}" "./${fname}" "false"
        done
    done
    killall emulationstation 2>/dev/null || true
}

cmd_status() {
    local count=0
    local hidden=0
    for sys in ${SYSTEMS}; do
        dst="${SHARE}/roms/${sys}"
        for link in $(find "${dst}" -maxdepth 1 -type l 2>/dev/null); do
            count=$((count + 1))
            fname=$(basename "${link}")
            gamelist="${dst}/gamelist.xml"
            if [ -f "${gamelist}" ]; then
                grep -q "<path>./${fname}</path>" "${gamelist}" && \
                grep -A5 "<path>./${fname}</path>" "${gamelist}" | grep -q "<hidden>true</hidden>" && \
                hidden=$((hidden + 1))
            fi
        done
    done
    echo "번들 게임: ${count}개 / 숨김: ${hidden}개"
}

case "$1" in
    init)   cmd_init   ;;
    hide)   cmd_hide   ;;
    show)   cmd_show   ;;
    status) cmd_status ;;
    *)
        echo "Usage: rpui-bundlegame {init|hide|show|status}"
        exit 1
        ;;
esac
