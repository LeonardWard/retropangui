#!/usr/bin/env bash
#
# 파일명: remove.sh
# 모듈 제거 함수
# ===============================================

# 개별 모듈 제거 함수
# 사용법: remove_module "모듈id" "모듈타입"
function remove_module() {
    local module_id="$1"
    local module_type="$2"

    if [[ -z "$module_id" || -z "$module_type" ]]; then
        log_msg ERROR "remove_module: Module ID 또는 Type이 제공되지 않았습니다."
        return 1
    fi

    source "$MODULES_DIR/compat/loader.sh"
    setup_env

    export md_id="$module_id"

    case "$module_type" in
        libretrocores)
            export md_inst="$LIBRETRO_CORE_PATH/$module_id"
            ;;
        emulators|ports)
            export md_inst="$INSTALL_ROOT_DIR/$module_type/$module_id"
            ;;
        *)
            log_msg ERROR "알 수 없는 모듈 타입입니다: $module_type"
            return 1
            ;;
    esac

    log_msg STEP "$module_id ($module_type) 모듈 제거를 시작합니다..."

    local script_path="$MODULES_DIR/retropie_setup/scriptmodules/$module_type/$module_id.sh"

    # 1. es_systems.xml에서 코어 정보 제거 (libretro 코어인 경우)
    if [[ "$module_type" == "libretrocores" ]]; then
        log_msg INFO "[$module_id] es_systems.xml에서 코어 정보를 제거합니다..."
        local so_name_file="$md_inst/.installed_so_name"
        if [[ -f "$so_name_file" ]]; then
            local so_filename=$(cat "$so_name_file")
            local core_name="${so_filename%_libretro.so}"

            if [[ -f "$script_path" ]]; then
                local raw_help=$(grep -oP 'rp_module_help="\K[^"]+' "$script_path" | head -1)
                local system_name=$(echo "$raw_help" | grep -oiP '\$romdir/\K[a-z0-9_-]+' | head -1)

                if [[ -n "$system_name" && -n "$core_name" ]]; then
                    source "$MODULES_DIR/lib/xml.sh"
                    remove_core_from_system "$system_name" "$core_name"
                else
                    log_msg WARN "[$module_id] es_systems.xml에서 제거할 시스템 또는 코어 이름을 확인할 수 없습니다."
                fi
            else
                log_msg WARN "[$module_id] 모듈 스크립트 파일을 찾을 수 없어 system 이름을 확인할 수 없습니다."
            fi
        else
            log_msg WARN "[$module_id] 설치된 코어 정보 파일(.installed_so_name)을 찾을 수 없어 es_systems.xml을 업데이트할 수 없습니다."
        fi
    fi

    # 2. 실제 파일 제거
    log_msg INFO "[$module_id] 설치된 파일을 제거합니다: $md_inst"
    if [[ -d "$md_inst" ]]; then
        sudo rm -rf "$md_inst"
        if [[ $? -eq 0 ]]; then
            log_msg SUCCESS "[$module_id] 디렉토리 제거 완료: $md_inst"
        else
            log_msg ERROR "[$module_id] 디렉토리 제거 실패: $md_inst"
            return 1
        fi
    else
        log_msg WARN "[$module_id] 설치 디렉토리를 찾을 수 없습니다: $md_inst"
    fi

    log_msg SUCCESS "$module_id 모듈 제거가 완료되었습니다."
    return 0
}
