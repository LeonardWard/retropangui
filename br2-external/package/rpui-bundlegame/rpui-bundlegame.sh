#!/bin/sh
# rpui-bundlegame - 번들 ROM 관리
#
#   init  : (2026-07-18부터) share에 물리 복사 없음. 대신 기본값(on)에 맞춰
#           show와 동일하게 gamelist.xml에 번들 항목을 채워넣는다. 예전
#           cp 방식(~2026-07-18)이 남긴 물리 파일/매니페스트가 있으면 정리.
#           S61share sentinel에서 1회 호출.
#   show  : 번들 게임을 share/roms/{sys}/gamelist.xml에 <game> 노드로 추가
#           (path/image는 스쿼시fs 절대경로로 다시 씀) + ES 재시작
#   hide  : share/roms/{sys}/gamelist.xml에서 번들 게임 <game> 노드를 제거
#           (게임 중 즐겨찾기/플레이횟수를 매겼어도 그대로 삭제 - 사용자 지시로
#           단순하게 처리) + ES 재시작
#   status: 현재 번들 게임 표시 여부 출력
#
# 2026-07-18 재설계(todo-20260704-es-multi-path-roms.html, 사용자 지시):
# 예전엔 부팅 시 번들 ROM을 share/roms/{sys}/에 cp로 복사해두고 hidden 플래그로
# 껐다 켰다 했음 - exFAT share 파티션이 번들 게임 용량을 그대로 차지하고,
# hide해도 물리 파일이 안 지워지는 문제가 있었음(사용자가 실기기에서 확인).
# 이제는 물리 복사를 아예 안 하고, share의 gamelist.xml이 스쿼시fs 안의
# bundled-roms/{sys}/ 경로를 직접 가리키게 한다 - ES의 findOrCreateFile()이
# 이 경로를 허용하도록 예외를 뒀음(Gamelist.cpp isBundledRomPath()).
# 번들 게임의 메타데이터(설명/이미지 등)는 bundled-roms/{sys}/gamelist.xml
# (빌드 시 큐레이션돼 스쿼시fs에 박힘)을 그대로 원본으로 삼는다 - 매니페스트가
# 더 이상 필요 없음(절대경로 prefix 자체가 "번들 게임"의 식별자).
#
# 2026-07-21 통합(사용자 지적: "같이 넣지 않은 이유가 있을 것 같은데 왜
# 안 넣었지?"): megadrive/msx1/msx2/scummvm이 SHOW BUNDLED GAMES 토글
# 대상에서 빠져있던 게 의도적 설계가 아니라 개발 순서 문제였음을 git
# 히스토리로 확인(download_extra_roms()가 2026-06-27에 먼저 생겼고,
# "번들 게임 + hide/show 토글" 개념 자체는 rpui-bundlegame이 도입된
# 2026-07-02 이후에 생김 - 나중에 만든 토글을 먼저 있던 기능으로
# 소급 적용하는 작업을 아무도 안 한 것뿐, 제외할 근거 있는 커밋 없음).
#
# 이 4개 시스템은 nes/snes/psx와 분배 방식 자체가 다름 - S61share의
# download_extra_roms()가 첫 부팅 때 네트워크에서 share/roms/{sys}/에
# 직접 내려받음(squashfs에 안 구움, 이미지 용량 때문으로 추정). 그래서
# nes/snes/psx처럼 "squashfs 절대경로를 gamelist.xml에 추가/제거"하는
# 방식을 그대로 못 씀 - 참조할 squashfs 사본이 없고, share에 있는 게
# 유일한 실물 사본이라 hide한다고 지웠다간 재다운로드 없이는 복구 불가.
# 대신 ES가 이미 네이티브로 지원하는 <hidden>true/false</hidden> 플래그를
# 씀(파일 삭제 없음, 노드 유지) - bundled-roms/{sys}/gamelist.xml(다운로드
# 때 시딩용으로 쓰는 그 템플릿)의 <path> 목록을 "이건 번들 게임이다"
# 식별용 매니페스트로 그대로 재사용(중복 하드코딩 없음).

SHARE="/retropangui/share"
BUNDLED="/usr/share/retropangui/bundled-roms"
# utility: 게임이 아니라 터미널 유틸리티 스크립트(2026-07-05) - 이건 계속
# 물리 복사 유지(실행 스크립트라 이 문서의 "번들 게임" 정리 범위 밖).
SYSTEMS="nes snes psx"
# 2026-07-21: squashfs 절대경로 방식이 아니라 <hidden> 플래그로 관리하는
# 시스템(download_extra_roms로 share에 직접 받아지는 것들).
SYSTEMS_DOWNLOADED="megadrive msx1 msx2 scummvm"
INIT_ONLY_SYSTEMS="utility"
# 예전(~2026-07-18) cp 방식이 남긴 흔적 정리용
MANIFEST_NAME=".bundled-manifest"

# retropangui.conf에서 system.bundlegame_show 값을 읽는다(없으면 기본값 true).
_read_bundlegame_show() {
    local conf="${SHARE}/system/retropangui.conf"
    local val=""
    [ -f "${conf}" ] && \
        val="$(grep -E '^[[:space:]]*system\.bundlegame_show[[:space:]]*=' "${conf}" 2>/dev/null | tail -1 | \
               sed 's/^[^=]*=//; s/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "${val}" ] && echo "${val}" || echo "true"
}

# gamelist.xml에서 <path>가 정확히 일치하는 <game> 노드 하나를 제거한다
# (예전 cp 방식이 남긴 상대경로 항목 정리용 - _gamelist_sync_bundled의
# 절대경로 매칭과는 다른 키라 별도 함수로 둠).
_gamelist_remove_exact_path() {
    local gamelist="$1"
    local relpath="$2"
    [ -f "${gamelist}" ] || return 0
    python3 - "${gamelist}" "${relpath}" <<'EOF'
import sys
import xml.etree.ElementTree as ET

gamelist, relpath = sys.argv[1], sys.argv[2]
tree = ET.parse(gamelist)
root = tree.getroot()
for g in root.findall('game'):
    p = g.find('path')
    if p is not None and p.text == relpath:
        root.remove(g)

ET.indent(tree, space='  ')
tree.write(gamelist, encoding='unicode', xml_declaration=True)
EOF
}

# 예전(~2026-07-18) cp 방식이 남긴 물리 파일·매니페스트·gamelist.xml 속
# 상대경로 항목을 정리하고, 현재 표시 설정이 on이면 새 절대경로 방식으로
# 다시 채워넣는다. sentinel과 무관하게 매 부팅 시도(idempotent) - 이미
# 정리된 기기에서는 매니페스트가 없어 즉시 반환.
_migrate_legacy_copies() {
    local migrated=0
    for sys in ${SYSTEMS}; do
        dst="${SHARE}/roms/${sys}"
        manifest="${dst}/${MANIFEST_NAME}"
        gamelist="${dst}/gamelist.xml"
        [ -f "${manifest}" ] || continue
        migrated=1
        while IFS= read -r rel; do
            [ -n "${rel}" ] || continue
            rm -f "${dst}/${rel}"
            _gamelist_remove_exact_path "${gamelist}" "./${rel}"
        done < "${manifest}"
        find "${dst}" -mindepth 1 -type d -empty -delete 2>/dev/null
        rm -f "${manifest}"
    done

    if [ "${migrated}" = "1" ]; then
        case "$(_read_bundlegame_show)" in
            false|0|no) : ;;  # 이미 껐던 기기는 다시 켜지 않음
            *) for sys in ${SYSTEMS}; do _gamelist_sync_bundled "${sys}" "add"; done ;;
        esac
    fi

    # 2026-07-21: SYSTEMS_DOWNLOADED(megadrive/msx1/msx2/scummvm)는 이번에
    # 처음 토글 대상에 편입돼서, 이미 부팅된 적 있는 기기는 예전 상태(항상
    # 표시)로 남아있을 수 있음 - migrated 여부와 무관하게 매 부팅 현재
    # bundlegame_show 값을 그대로 적용해 동기화(idempotent, 변경 없으면
    # 파일도 안 건드림 - _gamelist_set_hidden_downloaded의 changed 체크).
    local show_now
    case "$(_read_bundlegame_show)" in
        false|0|no) show_now="true" ;;   # hidden=true
        *)          show_now="false" ;;  # hidden=false
    esac
    for sys in ${SYSTEMS_DOWNLOADED}; do
        _gamelist_set_hidden_downloaded "${sys}" "${show_now}"
    done
}

# gamelist.xml에 번들 게임 <game> 노드를 추가(action=add)하거나 제거
# (action=remove)한다. 원본은 bundled-roms/{sys}/gamelist.xml - path/image를
# 스쿼시fs 절대경로로 다시 써서 dst gamelist.xml에 병합한다.
_gamelist_sync_bundled() {
    local sys="$1"
    local action="$2"
    local bundled_src="${BUNDLED}/${sys}/gamelist.xml"
    local dst="${SHARE}/roms/${sys}"
    local dst_gamelist="${dst}/gamelist.xml"

    [ -f "${bundled_src}" ] || return 0
    [ -d "${dst}" ] || return 0
    [ -f "${dst_gamelist}" ] || printf '<?xml version="1.0"?>\n<gameList>\n</gameList>\n' > "${dst_gamelist}"

    python3 - "${bundled_src}" "${dst_gamelist}" "${BUNDLED}/${sys}" "${action}" <<'EOF'
import sys, copy
import xml.etree.ElementTree as ET

bundled_src, dst_gamelist, bundled_root, action = sys.argv[1:5]
bundled_root = bundled_root.rstrip('/')

def to_abs(relpath):
    rel = relpath[2:] if relpath.startswith('./') else relpath
    return bundled_root + '/' + rel

bsrc_root = ET.parse(bundled_src).getroot()
bundled_games = bsrc_root.findall('game')

dst_tree = ET.parse(dst_gamelist)
dst_root = dst_tree.getroot()

existing_by_path = {}
for g in dst_root.findall('game'):
    p = g.find('path')
    if p is not None and p.text:
        existing_by_path[p.text] = g

for bg in bundled_games:
    p = bg.find('path')
    if p is None or not p.text:
        continue
    abspath = to_abs(p.text)

    old = existing_by_path.pop(abspath, None)
    if old is not None:
        dst_root.remove(old)

    if action != 'add':
        continue

    new_game = copy.deepcopy(bg)
    new_game.find('path').text = abspath
    img = new_game.find('image')
    if img is not None and img.text:
        img.text = to_abs(img.text)
    dst_root.append(new_game)

ET.indent(dst_tree, space='  ')
dst_tree.write(dst_gamelist, encoding='unicode', xml_declaration=True)
EOF
}

# SYSTEMS_DOWNLOADED(download_extra_roms로 share에 직접 받아지는 시스템)용 -
# squashfs 절대경로 참조가 없으므로 노드를 지우고 다시 만드는 대신 ES
# 네이티브 <hidden> 플래그만 토글한다(파일은 항상 share에 그대로 있음).
# "번들 게임"으로 볼 상대경로 목록은 bundled-roms/{sys}/gamelist.xml(다운로드
# 시딩에도 쓰는 그 템플릿)의 <path>에서 그대로 읽어옴 - 사용자가 직접 추가한
# 같은 시스템의 다른 게임은 이 목록에 없으니 건드리지 않음.
_gamelist_set_hidden_downloaded() {
    local sys="$1"
    local hidden="$2"  # "true" | "false"
    local bundled_src="${BUNDLED}/${sys}/gamelist.xml"
    local dst_gamelist="${SHARE}/roms/${sys}/gamelist.xml"

    [ -f "${bundled_src}" ] || return 0
    [ -f "${dst_gamelist}" ] || return 0

    python3 - "${bundled_src}" "${dst_gamelist}" "${hidden}" <<'EOF'
import sys
import xml.etree.ElementTree as ET

bundled_src, dst_gamelist, hidden = sys.argv[1:4]

bundled_paths = set()
for g in ET.parse(bundled_src).getroot().findall('game'):
    p = g.find('path')
    if p is not None and p.text:
        bundled_paths.add(p.text)

tree = ET.parse(dst_gamelist)
root = tree.getroot()
changed = False
for g in root.findall('game'):
    p = g.find('path')
    if p is None or p.text not in bundled_paths:
        continue
    h = g.find('hidden')
    if h is None:
        h = ET.SubElement(g, 'hidden')
    if h.text != hidden:
        h.text = hidden
        changed = True

if changed:
    ET.indent(tree, space='  ')
    tree.write(dst_gamelist, encoding='unicode', xml_declaration=True)
EOF
}

cmd_init() {
    _migrate_legacy_copies

    # utility(터미널 스크립트)는 계속 물리 복사 - 실행 스크립트라 번들
    # 게임(ROM) 정리 범위 밖. 실행권한 보존.
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

    # 번들 게임(nes/snes/psx)은 물리 복사 없이 gamelist.xml에만 반영.
    # 기본값이 on(retropangui.conf.default: system.bundlegame_show=true)이라
    # 최초 부팅 시엔 항상 show와 동일하게 채워넣는다 - 이후 껐다 켰다는
    # GuiMenu의 실시간 토글(cmd_show/cmd_hide)이 담당.
    for sys in ${SYSTEMS}; do
        _gamelist_sync_bundled "${sys}" "add"
    done
}

cmd_hide() {
    for sys in ${SYSTEMS}; do
        _gamelist_sync_bundled "${sys}" "remove"
    done
    # 2026-07-21: SYSTEMS_DOWNLOADED는 squashfs 사본이 없어 노드를 지우는
    # 대신 <hidden>true</hidden>만 세움(파일은 share에 그대로 유지) - 위
    # 헤더 주석 참고.
    for sys in ${SYSTEMS_DOWNLOADED}; do
        _gamelist_set_hidden_downloaded "${sys}" "true"
    done
    # 2026-07-12: killall emulationstation 제거 - 외부 SIGTERM은 타이밍에
    # 따라 ES가 GPU/DRM 작업 도중 끊겨서 다음 실행 때 화면이 안 나오는
    # 문제가 실기기에서 확인됨(DRM plane 없음). 재시작은 호출부(ES 자신의
    # GuiMenu.cpp)가 quitES()로 안전하게 처리함 - 여기선 gamelist.xml만 갱신.
}

cmd_show() {
    for sys in ${SYSTEMS}; do
        _gamelist_sync_bundled "${sys}" "add"
    done
    for sys in ${SYSTEMS_DOWNLOADED}; do
        _gamelist_set_hidden_downloaded "${sys}" "false"
    done
    # 2026-07-12: killall emulationstation 제거 - cmd_hide 주석 참고.
}

cmd_status() {
    local count=0
    local shown=0
    for sys in ${SYSTEMS}; do
        bundled_src="${BUNDLED}/${sys}/gamelist.xml"
        dst_gamelist="${SHARE}/roms/${sys}/gamelist.xml"
        [ -f "${bundled_src}" ] || continue
        n=$(grep -c "<path>" "${bundled_src}" 2>/dev/null || echo 0)
        count=$((count + n))
        if [ -f "${dst_gamelist}" ]; then
            m=$(python3 - "${bundled_src}" "${dst_gamelist}" "${BUNDLED}/${sys}" <<'EOF'
import sys
import xml.etree.ElementTree as ET

bundled_src, dst_gamelist, bundled_root = sys.argv[1:4]
bundled_root = bundled_root.rstrip('/')

def to_abs(relpath):
    rel = relpath[2:] if relpath.startswith('./') else relpath
    return bundled_root + '/' + rel

bpaths = set()
for g in ET.parse(bundled_src).getroot().findall('game'):
    p = g.find('path')
    if p is not None and p.text:
        bpaths.add(to_abs(p.text))

dpaths = set()
for g in ET.parse(dst_gamelist).getroot().findall('game'):
    p = g.find('path')
    if p is not None and p.text:
        dpaths.add(p.text)

print(len(bpaths & dpaths))
EOF
)
            shown=$((shown + m))
        fi
    done

    # 2026-07-21: SYSTEMS_DOWNLOADED - <hidden> 플래그 기준으로 카운트.
    for sys in ${SYSTEMS_DOWNLOADED}; do
        bundled_src="${BUNDLED}/${sys}/gamelist.xml"
        dst_gamelist="${SHARE}/roms/${sys}/gamelist.xml"
        [ -f "${bundled_src}" ] || continue
        n=$(grep -c "<path>" "${bundled_src}" 2>/dev/null || echo 0)
        count=$((count + n))
        if [ -f "${dst_gamelist}" ]; then
            m=$(python3 - "${bundled_src}" "${dst_gamelist}" <<'EOF'
import sys
import xml.etree.ElementTree as ET

bundled_src, dst_gamelist = sys.argv[1:3]

bpaths = set()
for g in ET.parse(bundled_src).getroot().findall('game'):
    p = g.find('path')
    if p is not None and p.text:
        bpaths.add(p.text)

visible = 0
for g in ET.parse(dst_gamelist).getroot().findall('game'):
    p = g.find('path')
    if p is None or p.text not in bpaths:
        continue
    h = g.find('hidden')
    if h is None or h.text not in ('true', '1'):
        visible += 1
print(visible)
EOF
)
            shown=$((shown + m))
        fi
    done

    echo "번들 게임: ${count}개 / 표시: ${shown}개"
}

case "$1" in
    init)    cmd_init             ;;
    hide)    cmd_hide             ;;
    show)    cmd_show             ;;
    status)  cmd_status           ;;
    migrate) _migrate_legacy_copies ;;
    *)
        echo "Usage: $0 {init|hide|show|status|migrate}"
        exit 1
        ;;
esac
