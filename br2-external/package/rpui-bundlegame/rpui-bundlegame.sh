#!/bin/sh
# rpui-bundlegame - 번들 ROM 관리
#
#   init  : 이미지 내 번들 ROM → share/roms/{sys}/ 로 복사 (S61share sentinel에서 1회 호출)
#           share 파티션이 exFAT라 심볼릭 링크가 안 먹힘("Operation not permitted") —
#           2026-07-04 확인. cp로 복사하고, 어떤 파일이 번들 것인지는
#           roms/{sys}/.bundled-manifest 에 상대경로(폴더 포함)를 기록해서 구분한다.
#   hide  : 번들 게임 gamelist.xml hidden 처리 + ES 재시작
#   show  : 번들 게임 gamelist.xml hidden 해제 + ES 재시작
#   status: 현재 번들 게임 표시 여부 출력
#
# 2026-07-15: 번들 게임을 게임별 폴더로 배치하는 구조(todo-20260714-
# bundled-game-curation)로 바뀌면서 파일 단위 순회를 재귀(find)로 교체하고,
# 매니페스트도 파일명 단독이 아니라 "폴더/파일명" 상대경로를 저장한다.
# 이 값을 다시 순회할 때 `for x in $(...)` 방식은 공백이 든 폴더명(예:
# "240p Test Suite")에서 단어 분리 버그가 나므로 전부 `while read` +
# 파일 리다이렉션(파이프 아님 - 서브셸이라 카운터 변수가 안 살아남음)으로 처리한다.

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
        find "${src}" -type f | while IFS= read -r f; do
            rel="${f#${src}/}"
            mkdir -p "${dst}/$(dirname "${rel}")"
            cp -f "${f}" "${dst}/${rel}" 2>/dev/null && echo "${rel}" >> "${manifest}"
        done
    done
    # hide/show 대상이 아닌 것들 — 매니페스트 없이 그냥 복사만(실행권한 보존)
    for sys in ${INIT_ONLY_SYSTEMS}; do
        src="${BUNDLED}/${sys}"
        dst="${SHARE}/roms/${sys}"
        [ -d "${src}" ] || continue
        [ -d "${dst}" ] || continue
        find "${src}" -type f | while IFS= read -r f; do
            rel="${f#${src}/}"
            mkdir -p "${dst}/$(dirname "${rel}")"
            cp -f "${f}" "${dst}/${rel}" 2>/dev/null
        done
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
        manifest="${dst}/${MANIFEST_NAME}"
        [ -d "${dst}" ] || continue
        [ -f "${manifest}" ] || continue
        while IFS= read -r rel; do
            [ -n "${rel}" ] || continue
            _gamelist_set_hidden "${gamelist}" "./${rel}" "true"
        done < "${manifest}"
    done
    # 2026-07-12: killall emulationstation 제거 - 외부 SIGTERM은 타이밍에
    # 따라 ES가 GPU/DRM 작업 도중 끊겨서 다음 실행 때 화면이 안 나오는
    # 문제가 실기기에서 확인됨(DRM plane 없음). 재시작은 호출부(ES 자신의
    # GuiMenu.cpp)가 quitES()로 안전하게 처리함 - 여기선 gamelist.xml만 갱신.
}

cmd_show() {
    for sys in ${SYSTEMS}; do
        dst="${SHARE}/roms/${sys}"
        gamelist="${dst}/gamelist.xml"
        manifest="${dst}/${MANIFEST_NAME}"
        [ -d "${dst}" ] || continue
        [ -f "${manifest}" ] || continue
        while IFS= read -r rel; do
            [ -n "${rel}" ] || continue
            _gamelist_set_hidden "${gamelist}" "./${rel}" "false"
        done < "${manifest}"
    done
    # 2026-07-12: killall emulationstation 제거 - cmd_hide 주석 참고.
}

cmd_status() {
    local count=0
    local hidden=0
    for sys in ${SYSTEMS}; do
        dst="${SHARE}/roms/${sys}"
        gamelist="${dst}/gamelist.xml"
        manifest="${dst}/${MANIFEST_NAME}"
        [ -f "${manifest}" ] || continue
        while IFS= read -r rel; do
            [ -n "${rel}" ] || continue
            count=$((count + 1))
            if [ -f "${gamelist}" ]; then
                grep -q "<path>./${rel}</path>" "${gamelist}" && \
                grep -A5 "<path>./${rel}</path>" "${gamelist}" | grep -q "<hidden>true</hidden>" && \
                hidden=$((hidden + 1))
            fi
        done < "${manifest}"
    done
    echo "번들 게임: ${count}개 / 숨김: ${hidden}개"
}

case "$1" in
    init)   cmd_init   ;;
    hide)   cmd_hide   ;;
    show)   cmd_show   ;;
    status) cmd_status ;;
    *)
        echo "Usage: $0 {init|hide|show|status}"
        exit 1
        ;;
esac
