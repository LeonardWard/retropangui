#!/bin/sh
# rpui-bundlegame - 번들 ROM 관리
#
#   init  : 이미지 내 번들 ROM → share/roms/{sys}/ 로 복사 (S61share sentinel에서 1회 호출)
#           share 파티션이 exFAT라 심볼릭 링크가 안 먹힘("Operation not permitted") —
#           2026-07-04 확인. cp로 복사하고, 어떤 파일이 번들 것인지는
#           roms/{sys}/.bundled-manifest 에 파일명을 기록해서 구분한다.
#   hide  : 번들 게임 gamelist.xml hidden 처리 + ES 재시작
#   show  : 번들 게임 gamelist.xml hidden 해제 + ES 재시작
#   status: 현재 번들 게임 표시 여부 출력

SHARE="/retropangui/share"
BUNDLED="/usr/share/retropangui/bundled-roms"
# utility: 게임이 아니라 터미널 유틸리티 스크립트(2026-07-05) — hide/show
# 대상은 아니지만 init(최초 복사)에는 같이 포함시켜서 재사용
SYSTEMS="nes snes psx"
INIT_ONLY_SYSTEMS="utility"
MANIFEST_NAME=".bundled-manifest"

cmd_init() {
    for sys in ${SYSTEMS}; do
        src="${BUNDLED}/${sys}"
        dst="${SHARE}/roms/${sys}"
        [ -d "${src}" ] || continue
        [ -d "${dst}" ] || continue
        manifest="${dst}/${MANIFEST_NAME}"
        : > "${manifest}"
        for f in "${src}"/*; do
            [ -f "${f}" ] || continue
            fname=$(basename "${f}")
            cp -f "${f}" "${dst}/${fname}" 2>/dev/null && echo "${fname}" >> "${manifest}"
        done
    done
    # hide/show 대상이 아닌 것들 — 매니페스트 없이 그냥 복사만(실행권한 보존)
    for sys in ${INIT_ONLY_SYSTEMS}; do
        src="${BUNDLED}/${sys}"
        dst="${SHARE}/roms/${sys}"
        [ -d "${src}" ] || continue
        [ -d "${dst}" ] || continue
        for f in "${src}"/*; do
            [ -f "${f}" ] || continue
            fname=$(basename "${f}")
            cp -f "${f}" "${dst}/${fname}" 2>/dev/null
        done
    done
}

# 저장된 매니페스트에서 이 시스템의 번들 파일명 목록을 반환
_bundled_names() {
    sys="$1"
    manifest="${SHARE}/roms/${sys}/${MANIFEST_NAME}"
    [ -f "${manifest}" ] && cat "${manifest}"
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
        for fname in $(_bundled_names "${sys}"); do
            _gamelist_set_hidden "${gamelist}" "./${fname}" "true"
        done
    done
    killall emulationstation 2>/dev/null || true
}

cmd_show() {
    for sys in ${SYSTEMS}; do
        dst="${SHARE}/roms/${sys}"
        gamelist="${dst}/gamelist.xml"
        [ -d "${dst}" ] || continue
        for fname in $(_bundled_names "${sys}"); do
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
        gamelist="${dst}/gamelist.xml"
        for fname in $(_bundled_names "${sys}"); do
            count=$((count + 1))
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
