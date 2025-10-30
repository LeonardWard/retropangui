#!/usr/bin/env bash

# es_systems_updater.sh
# XML 업데이트 함수 모음: es_systems.xml에 코어 정보를 동적으로 추가/제거

# config.sh에서 환경변수 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

ES_SYSTEMS_XML="${ES_CONFIG_DIR}/es_systems.xml"

# xmlstarlet 설치 확인
ensure_xmlstarlet() {
    if ! command -v xmlstarlet &> /dev/null; then
        echo "[INFO] xmlstarlet이 설치되어 있지 않습니다. 설치 중..."
        sudo apt-get update && sudo apt-get install -y xmlstarlet
    fi
}

# XML 파일 권한을 사용자로 복원
# sudo로 실행 시 root 소유가 되는 것을 방지
fix_xml_permissions() {
    if [[ ! -f "$ES_SYSTEMS_XML" ]]; then
        return 0
    fi

    local target_user="$(get_effective_user)"
    if [[ -z "$target_user" ]]; then
        log_msg WARN "유효 사용자 이름 결정 실패. 권한 설정을 건너뜁니다."
        return 0
    fi

    chown "$target_user:$target_user" "$ES_SYSTEMS_XML" 2>/dev/null || true
}

# 백업 생성
backup_es_systems() {
    local backup_file="${ES_SYSTEMS_XML}.backup.$(date +%Y%m%d_%H%M%S)"
    if [[ -f "$ES_SYSTEMS_XML" ]]; then
        cp "$ES_SYSTEMS_XML" "$backup_file"
        echo "[INFO] 백업 생성: $backup_file"
    fi
}

# 시스템이 존재하는지 확인
system_exists() {
    local system_name="$1"
    xmlstarlet sel -t -v "count(/systemList/system[name='$system_name'])" "$ES_SYSTEMS_XML" 2>/dev/null
}

# 시스템에 cores 노드가 있는지 확인
has_cores_node() {
    local system_name="$1"
    local count=$(xmlstarlet sel -t -v "count(/systemList/system[name='$system_name']/cores)" "$ES_SYSTEMS_XML" 2>/dev/null)
    [[ "$count" -gt 0 ]]
}

# cores 노드 생성 (없는 경우)
ensure_cores_node() {
    local system_name="$1"

    if ! has_cores_node "$system_name"; then
        echo "[INFO] 시스템 '$system_name'에 <cores> 노드 생성 중..."
        xmlstarlet ed -L \
            -s "/systemList/system[name='$system_name']" -t elem -n "cores" \
            "$ES_SYSTEMS_XML"
        fix_xml_permissions
    fi
}

# 시스템 자동 생성
# 사용법: create_system <system_name> <extensions>
create_system() {
    local system_name="$1"
    local extensions="$2"

    # fullname: 시스템 이름을 대문자로 시작
    local fullname=$(echo "$system_name" | sed 's/.*/\u&/')

    # path: $USER_ROMS_PATH/$system_name (환경변수에서 읽거나 기본값)
    local roms_path="${USER_ROMS_PATH:-$HOME/share/roms}"
    local system_path="$roms_path/$system_name"

    # command: RetroArch 템플릿
    local retroarch_path="${RETROARCH_BIN_PATH:-/opt/retropangui/bin/retroarch}"
    local command="$retroarch_path -L %CORE% --config %CONFIG% %ROM%"

    echo "[INFO] 시스템 '$system_name' 자동 생성 중..."

    # 시스템 XML 생성
    local tmp_file=$(mktemp)
    xmlstarlet ed \
        -s "/systemList" -t elem -n "system_tmp" \
        -s "//system_tmp" -t elem -n "name" -v "$system_name" \
        -s "//system_tmp" -t elem -n "fullname" -v "$fullname" \
        -s "//system_tmp" -t elem -n "path" -v "$system_path" \
        -s "//system_tmp" -t elem -n "extension" -v "$extensions" \
        -s "//system_tmp" -t elem -n "cores" \
        -s "//system_tmp" -t elem -n "command" -v "$command" \
        -s "//system_tmp" -t elem -n "platform" -v "$system_name" \
        -s "//system_tmp" -t elem -n "theme" -v "$system_name" \
        -r "//system_tmp" -v "system" \
        "$ES_SYSTEMS_XML" > "$tmp_file"

    if [[ $? -eq 0 ]]; then
        mv "$tmp_file" "$ES_SYSTEMS_XML"
        fix_xml_permissions
        echo "[SUCCESS] 시스템 '$system_name' 생성 완료"

        # ROM 디렉토리도 생성
        mkdir -p "$system_path"
        echo "[INFO] ROM 디렉토리 생성: $system_path"
        return 0
    else
        echo "[ERROR] 시스템 생성 실패"
        rm -f "$tmp_file"
        return 1
    fi
}

# 특정 시스템에 코어 추가
# 사용법: add_core_to_system <system_name> <core_name> <module_id> <priority> <extensions> [fullname]
add_core_to_system() {
    local system_name="$1"
    local core_name="$2"
    local module_id="$3"
    local priority="$4"
    local extensions="$5"  # e.g., ".cue .bin .iso"
    local fullname="$6"    # e.g., "PCSX ReARMed" (optional)

    if [[ -z "$system_name" || -z "$core_name" || -z "$module_id" ]]; then
        echo "[ERROR] add_core_to_system: system_name, core_name, module_id는 필수입니다."
        return 1
    fi

    # fullname이 없으면 core_name 사용
    if [[ -z "$fullname" ]]; then
        fullname="$core_name"
    fi

    ensure_xmlstarlet

    if [[ ! -f "$ES_SYSTEMS_XML" ]]; then
        echo "[ERROR] es_systems.xml 파일을 찾을 수 없습니다: $ES_SYSTEMS_XML"
        return 1
    fi

    # 시스템 존재 확인
    local sys_count=$(system_exists "$system_name")
    if [[ "$sys_count" -eq 0 ]]; then
        echo "[INFO] 시스템 '$system_name'이 없습니다. 자동 생성합니다..."
        create_system "$system_name" "$extensions" || return 1
    fi

    ensure_cores_node "$system_name"

    # 코어가 이미 존재하는지 확인
    local core_count=$(xmlstarlet sel -t -v "count(/systemList/system[name='$system_name']/cores/core[@name='$core_name'])" "$ES_SYSTEMS_XML" 2>/dev/null)

    if [[ "$core_count" -gt 0 ]]; then
        echo "[INFO] 코어 '$core_name'이 이미 시스템 '$system_name'에 존재합니다. 업데이트 중..."
        # 기존 코어 제거
        xmlstarlet ed -L \
            -d "/systemList/system[name='$system_name']/cores/core[@name='$core_name']" \
            "$ES_SYSTEMS_XML"
        fix_xml_permissions
    fi

    # 새 코어 추가
    echo "[INFO] 코어 추가: system=$system_name, core=$core_name, module_id=$module_id, priority=$priority, fullname=$fullname"

    # 임시 파일 생성 후 치환
    local tmp_file=$(mktemp)
    xmlstarlet ed \
        -s "/systemList/system[name='$system_name']/cores" -t elem -n "core_tmp" \
        -i "//core_tmp" -t attr -n "name" -v "$core_name" \
        -i "//core_tmp" -t attr -n "fullname" -v "$fullname" \
        -i "//core_tmp" -t attr -n "module_id" -v "$module_id" \
        -i "//core_tmp" -t attr -n "priority" -v "${priority:-999}" \
        -i "//core_tmp" -t attr -n "extensions" -v "$extensions" \
        -r "//core_tmp" -v "core" \
        "$ES_SYSTEMS_XML" > "$tmp_file"

    if [[ $? -eq 0 ]]; then
        mv "$tmp_file" "$ES_SYSTEMS_XML"
        fix_xml_permissions
        echo "[SUCCESS] 코어 '$core_name'이 시스템 '$system_name'에 추가되었습니다."
        return 0
    else
        echo "[ERROR] XML 업데이트 실패"
        rm -f "$tmp_file"
        return 1
    fi
}

# 특정 시스템에서 코어 제거
# 사용법: remove_core_from_system <system_name> <core_name>
remove_core_from_system() {
    local system_name="$1"
    local core_name="$2"

    if [[ -z "$system_name" || -z "$core_name" ]]; then
        echo "[ERROR] remove_core_from_system: system_name, core_name은 필수입니다."
        return 1
    fi

    ensure_xmlstarlet

    if [[ ! -f "$ES_SYSTEMS_XML" ]]; then
        echo "[ERROR] es_systems.xml 파일을 찾을 수 없습니다: $ES_SYSTEMS_XML"
        return 1
    fi

    echo "[INFO] 코어 제거: system=$system_name, core=$core_name"
    xmlstarlet ed -L \
        -d "/systemList/system[name='$system_name']/cores/core[@name='$core_name']" \
        "$ES_SYSTEMS_XML"
    fix_xml_permissions

    echo "[SUCCESS] 코어 '$core_name'이 시스템 '$system_name'에서 제거되었습니다."
}

# 코어 정보 조회
# 사용법: get_core_info <system_name> <core_name>
get_core_info() {
    local system_name="$1"
    local core_name="$2"

    ensure_xmlstarlet

    if [[ ! -f "$ES_SYSTEMS_XML" ]]; then
        echo "[ERROR] es_systems.xml 파일을 찾을 수 없습니다: $ES_SYSTEMS_XML"
        return 1
    fi

    xmlstarlet sel -t \
        -m "/systemList/system[name='$system_name']/cores/core[@name='$core_name']" \
        -v "concat('name=', @name, '|module_id=', @module_id, '|priority=', @priority, '|extensions=', @extensions)" \
        "$ES_SYSTEMS_XML"
}

# 시스템의 모든 코어 목록 출력
# 사용법: list_cores <system_name>
list_cores() {
    local system_name="$1"

    ensure_xmlstarlet

    if [[ ! -f "$ES_SYSTEMS_XML" ]]; then
        echo "[ERROR] es_systems.xml 파일을 찾을 수 없습니다: $ES_SYSTEMS_XML"
        return 1
    fi

    echo "[INFO] 시스템 '$system_name'의 코어 목록:"
    xmlstarlet sel -t \
        -m "/systemList/system[name='$system_name']/cores/core" \
        -v "concat('  - ', @name, ' (module_id=', @module_id, ', priority=', @priority, ')')" -n \
        "$ES_SYSTEMS_XML"
}

# 시스템의 기본 코어 설정 (priority 재배치)
# 사용법: set_default_core <system_name> <core_name>
# 선택한 core를 priority=1로, 나머지는 +1씩 증가
set_default_core() {
    local system_name="$1"
    local target_core="$2"

    if [[ -z "$system_name" || -z "$target_core" ]]; then
        echo "[ERROR] set_default_core: system_name, core_name은 필수입니다."
        return 1
    fi

    ensure_xmlstarlet

    if [[ ! -f "$ES_SYSTEMS_XML" ]]; then
        echo "[ERROR] es_systems.xml 파일을 찾을 수 없습니다: $ES_SYSTEMS_XML"
        return 1
    fi

    # 대상 코어가 존재하는지 확인
    local core_exists=$(xmlstarlet sel -t -v "count(/systemList/system[name='$system_name']/cores/core[@name='$target_core'])" "$ES_SYSTEMS_XML" 2>/dev/null)
    if [[ "$core_exists" -eq 0 ]]; then
        echo "[ERROR] 코어 '$target_core'가 시스템 '$system_name'에 존재하지 않습니다."
        return 1
    fi

    echo "[INFO] 시스템 '$system_name'의 기본 코어를 '$target_core'로 설정 중..."

    # 백업 생성
    backup_es_systems

    # 임시 파일 생성
    local tmp_file=$(mktemp)

    # 1단계: 모든 코어의 priority를 +1
    xmlstarlet ed \
        -u "/systemList/system[name='$system_name']/cores/core/@priority" \
        -x ". + 1" \
        "$ES_SYSTEMS_XML" > "$tmp_file"

    # 2단계: 선택한 코어를 priority=1로 설정
    xmlstarlet ed -L \
        -u "/systemList/system[name='$system_name']/cores/core[@name='$target_core']/@priority" \
        -v "1" \
        "$tmp_file"

    if [[ $? -eq 0 ]]; then
        mv "$tmp_file" "$ES_SYSTEMS_XML"
        fix_xml_permissions
        echo "[SUCCESS] 시스템 '$system_name'의 기본 코어가 '$target_core'로 설정되었습니다."
        return 0
    else
        echo "[ERROR] priority 업데이트 실패"
        rm -f "$tmp_file"
        return 1
    fi
}

# 메인 실행 (테스트용)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "es_systems_updater.sh - ES Systems XML 업데이트 도구"
    echo "이 스크립트는 직접 실행하는 것이 아니라 다른 스크립트에서 source하여 사용합니다."
    echo ""
    echo "사용 가능한 함수:"
    echo "  - add_core_to_system <system> <core_name> <module_id> <priority> <extensions>"
    echo "  - remove_core_from_system <system> <core_name>"
    echo "  - get_core_info <system> <core_name>"
    echo "  - list_cores <system>"
fi
