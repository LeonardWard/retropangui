#!/usr/bin/env bash
#
# 파일명: special.sh
# 특수 케이스 및 ES Systems XML 업데이트 함수
# ===============================================

# 특수 케이스: 표준 형식을 따르지 않는 코어들의 정보 반환
function get_special_core_info() {
    local module_id="$1"
    local info_type="$2"  # "extensions" 또는 "system"

    case "$module_id" in
        lr-scummvm)
            if [[ "$info_type" == "extensions" ]]; then
                echo ".svm"
            elif [[ "$info_type" == "system" ]]; then
                echo "scummvm"
            fi
            ;;
        # 추가 특수 케이스는 여기에 추가
        *)
            echo ""
            ;;
    esac
}

# es_systems.xml에 코어 추가 (libretrocore 설치 후 자동 호출)
function update_es_systems_for_core() {
    local module_id="$1"
    local so_filename="$2"

    # lib/xml.sh 로드
    local updater_script="$MODULES_DIR/lib/xml.sh"
    if [[ ! -f "$updater_script" ]]; then
        log_msg WARN "[$module_id] lib/xml.sh를 찾을 수 없습니다. XML 업데이트 건너뜀."
        return 0
    fi

    source "$updater_script"

    # 코어 스크립트 파일 경로
    local script_path="$MODULES_DIR/retropie_setup/scriptmodules/libretrocores/$module_id.sh"
    if [[ ! -f "$script_path" ]]; then
        log_msg WARN "[$module_id] 코어 스크립트 파일을 찾을 수 없습니다: $script_path"
        return 0
    fi

    # 파일에서 직접 rp_module_help 추출 (변수 치환 없이)
    local raw_help=$(grep -oP 'rp_module_help="\K[^"]+' "$script_path" | head -1)

    # ROM Extensions 추출 (.bin .cue 등의 확장자 목록)
    # "ROM Extensions:" 또는 "ROM Extension:" 모두 지원 (대소문자 무시)
    local extensions=$(echo "$raw_help" | grep -oiP "ROM Extensions?:\s*\K[^\\\\]+?(?=\\\\n)" | head -1)

    # romdir 경로에서 시스템 이름 추출 (예: $romdir/psx -> psx)
    # $romdir, $ROMDIR 모두 지원 (대소문자 무시)
    local system_name=$(echo "$raw_help" | grep -oiP '\$romdir/\K[a-z0-9_-]+' | head -1)

    # 표준 방식으로 추출 실패 시 특수 케이스 확인
    if [[ -z "$system_name" ]]; then
        system_name=$(get_special_core_info "$module_id" "system")
        if [[ -z "$system_name" ]]; then
            log_msg WARN "[$module_id] 시스템 이름을 추출할 수 없습니다. XML 업데이트 건너뜀."
            return 0
        else
            log_msg INFO "[$module_id] 특수 케이스에서 시스템 이름 추출: $system_name"
        fi
    fi

    if [[ -z "$extensions" ]]; then
        extensions=$(get_special_core_info "$module_id" "extensions")
        if [[ -z "$extensions" ]]; then
            log_msg WARN "[$module_id] ROM Extensions를 추출할 수 없습니다. XML 업데이트 건너뜀."
            return 0
        else
            log_msg INFO "[$module_id] 특수 케이스에서 확장자 추출: $extensions"
        fi
    fi

    # 코어 이름 추출 (.so 파일명에서 _libretro.so 제거)
    local core_name="${so_filename%_libretro.so}"

    # priorities.conf에서 priority와 fullname 조회
    # config.sh에서 export된 MODULES_DIR 사용
    local priority_file="$MODULES_DIR/resources/priorities.conf"
    local priority=999
    local fullname=""

    if [[ -f "$priority_file" ]]; then
        # Format: module_id:system_name:priority:fullname
        local priority_line=$(grep "^${module_id}:${system_name}:" "$priority_file" | head -1)
        if [[ -n "$priority_line" ]]; then
            priority=$(echo "$priority_line" | cut -d: -f3)
            fullname=$(echo "$priority_line" | cut -d: -f4)
            log_msg INFO "[$module_id] priorities 파일에서 읽음: priority=$priority, fullname=$fullname"
        else
            log_msg WARN "[$module_id] priorities 파일에 항목 없음. 기본값 사용: priority=999"
        fi
    else
        log_msg WARN "priorities 파일 없음: $priority_file"
    fi

    log_msg INFO "[$module_id] es_systems.xml 업데이트: system=$system_name, core=$core_name, module_id=$module_id, priority=$priority, fullname=$fullname, extensions=$extensions"

    # es_systems.xml에 추가
    add_core_to_system "$system_name" "$core_name" "$module_id" "$priority" "$extensions" "$fullname" || {
        log_msg WARN "[$module_id] es_systems.xml 업데이트 실패"
        return 1
    }

    log_msg SUCCESS "[$module_id] es_systems.xml 업데이트 완료"
    return 0
}
