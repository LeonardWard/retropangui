#!/usr/bin/env bash
#
# 파일명: packages_utils.sh
# 패키지 관리 유틸리티 함수
# ===============================================

# 모듈이 설치되었는지 확인하는 함수
# $1: 모듈 ID, $2: 모듈 타입 (libretrocores, emulators, ports)
function is_module_installed() {
    local module_id="$1"
    local module_type="$2"

    log_msg DEBUG "is_module_installed 호출: module_id=$module_id, module_type=$module_type"

    case "$module_type" in
        libretrocores)
            local module_dir="$LIBRETRO_CORE_PATH/$module_id"
            local metadata_file="$module_dir/.installed_so_name"
            log_msg DEBUG "  Libretrocore: metadata_file=$metadata_file"
            if [[ -f "$metadata_file" ]]; then
                log_msg DEBUG "  메타데이터 파일 존재."
                local so_file_name=$(cat "$metadata_file")
                local so_path="$module_dir/$so_file_name"
                log_msg DEBUG "  메타데이터에서 so_file_name=$so_file_name, so_path=$so_path"
                if [[ -f "$so_path" ]]; then
                    log_msg DEBUG "  $so_path 파일 존재. 설치됨."
                    return 0
                else
                    log_msg DEBUG "  $so_path 파일 없음. 설치 안됨."
                    return 1
                fi
            else
                log_msg DEBUG "  메타데이터 파일 없음. 폴백 로직 사용."
                local core_name="${module_id#lr-}"
                local so_path="$module_dir/${core_name}_libretro.so"
                log_msg DEBUG "  폴백: core_name=$core_name, so_path=$so_path"
                if [[ -f "$so_path" ]]; then
                    log_msg DEBUG "  $so_path 파일 존재. 설치됨."
                    return 0
                else
                    log_msg DEBUG "  $so_path 파일 없음. 설치 안됨."
                    return 1
                fi
            fi
            ;;
        emulators|ports)
            local install_path="$INSTALL_ROOT_DIR/$module_type/$module_id"
            log_msg DEBUG "  Emulator/Port: install_path=$install_path"
            if [[ -d "$install_path" ]]; then
                log_msg DEBUG "  $install_path 디렉토리 존재. 설치됨."
                return 0
            else
                log_msg DEBUG "  $install_path 디렉토리 없음. 설치 안됨."
                return 1
            fi
            ;;
        *)
            log_msg DEBUG "  알 수 없는 타입. 설치 안됨."
            return 1
            ;;
    esac
}

# rp_module_flags를 기반으로 현재 플랫폼에서 모듈을 사용할 수 있는지 확인하는 독립적인 함수
function rp_checkModulePlatform() {
    local flags_str="$1"
    local flags=($flags_str)

    # 1. 부정적 플래그 확인 (하나라도 일치하면 즉시 실패)
    for flag in "${flags[@]}"; do
        if [[ "$flag" == "!"* ]]; then
            local negated_flag="${flag:1}"
            if [[ "$negated_flag" == "all" ]]; then return 1; fi # !all 이면 무조건 실패
            for p_flag in "${__platform_flags[@]}"; do
                if [[ "$negated_flag" == "$p_flag" ]]; then return 1; fi # !<platform>
            done
        fi
    done

    # 2. 긍정적 플래그 확인 (플랫폼 지정 플래그가 하나라도 있을 경우)
    local has_positive_platform_req=0
    local platform_matched=0
    for flag in "${flags[@]}"; do
        # 플랫폼 관련 플래그만 고려 (nobin, frontend 등은 제외)
        if [[ "$flag" != "!"* && "$flag" != "nobin" && "$flag" != "noinstclean" && "$flag" != "frontend" && "$flag" != "nonet" && "$flag" != "sdl1" && "$flag" != "sdl2" && "$flag" != "videocore" && "$flag" != "dispmanx" && "$flag" != "kms" && "$flag" != "x11" && "$flag" != "mali" && "$flag" != "nodistcc" ]]; then
            has_positive_platform_req=1
            for p_flag in "${__platform_flags[@]}"; do
                if [[ "$flag" == "$p_flag" ]]; then
                    platform_matched=1
                    break
                fi
            done
        fi
    done

    # 긍정적 요구사항이 있었는데, 하나도 맞는게 없으면 실패
    if [[ $has_positive_platform_req -eq 1 && $platform_matched -eq 0 ]]; then
        return 1
    fi

    return 0
}

# 모든 스크립트 모듈을 검색하고, 현재 플랫폼에 맞는 패키지 정보를 반환하는 독립적인 함수
# $1: 설명 텍스트 최대 너비 (선택적, 기본값 40)
function get_all_packages() {
    local desc_max_width="${1:-40}"
    desc_max_width=$((desc_max_width * 90 / 100))
    [[ "$desc_max_width" -lt 20 ]] && desc_max_width=20

    local script_root="$MODULES_DIR/retropie_setup/scriptmodules"

    find "$script_root" -maxdepth 2 -type f -name "*.sh" | while read -r script_path; do
        local module_type=$(basename "$(dirname "$script_path")")

        if [[ "$module_type" == "scriptmodules" ]]; then
            continue
        fi

        local rp_module_id=""
        local rp_module_desc=""
        local rp_module_section=""
        local rp_module_flags=""

        while IFS= read -r line; do
            line="${line%%#*}"

            if [[ -z "$rp_module_id" && "$line" =~ rp_module_id[[:space:]]*= ]]; then
                rp_module_id=$(echo "$line" | sed -E 's/.*rp_module_id[[:space:]]*=[[:space:]]*//; s/^["'\'']*//; s/["'\'']*[[:space:]]*$//')
            elif [[ -z "$rp_module_desc" && "$line" =~ rp_module_desc[[:space:]]*= ]]; then
                rp_module_desc=$(echo "$line" | sed -E 's/.*rp_module_desc[[:space:]]*=[[:space:]]*//; s/^["'\'']*//; s/["'\'']*[[:space:]]*$//')
            elif [[ -z "$rp_module_section" && "$line" =~ rp_module_section[[:space:]]*= ]]; then
                rp_module_section=$(echo "$line" | sed -E 's/.*rp_module_section[[:space:]]*=[[:space:]]*//; s/^["'\'']*//; s/["'\'']*[[:space:]]*$//')
            elif [[ -z "$rp_module_flags" && "$line" =~ rp_module_flags[[:space:]]*= ]]; then
                rp_module_flags=$(echo "$line" | sed -E 's/.*rp_module_flags[[:space:]]*=[[:space:]]*//; s/^["'\''(]*//; s/["'\'')]*[[:space:]]*$//')
            fi
        done < "$script_path"

        if [[ -z "$rp_module_id" ]]; then
            log_msg DEBUG "Skipping (no id): $script_path"
            continue
        fi

        if ! rp_checkModulePlatform "$rp_module_flags"; then
            log_msg DEBUG "Skipping (platform): $rp_module_id (flags: $rp_module_flags)"
            continue
        fi

        local section="$rp_module_section"
        local final_section=$(echo "$section" | awk '{print $1}')
        for part in $section; do
            if [[ "$part" == *"="* ]]; then
                local platform_req=$(echo "$part" | cut -d'=' -f1)
                local new_section=$(echo "$part" | cut -d'=' -f2)
                for p_flag in "${__platform_flags[@]}"; do
                    if [[ "$platform_req" == "$p_flag" ]]; then
                        final_section="$new_section"
                        break 2
                    fi
                done
            fi
        done

        local status="OFF"
        if is_module_installed "$rp_module_id" "$module_type"; then
            status="ON"
        fi

        local truncated_desc="$rp_module_desc"
        if [[ ${#truncated_desc} -gt "$desc_max_width" ]]; then
            truncated_desc="${truncated_desc:0:$((desc_max_width - 3))}..."
        fi

        printf "%s\0%s\0%s\0%s\0%s\0" "$rp_module_id" "$truncated_desc" "$final_section" "$module_type" "$status"
    done
}

# get_all_packages의 결과물을 기반으로 업데이트 상태를 추가하는 래퍼 함수
function get_packages_with_update_status() {
    # get_all_packages는 null 문자로 구분된 스트림을 출력합니다.
    get_all_packages "$@" | while IFS= read -r -d '' id && IFS= read -r -d '' desc && IFS= read -r -d '' section && IFS= read -r -d '' type && IFS= read -r -d '' status; do

        local final_status="$status"

        # 모듈이 이미 설치된 경우에만 업데이트 확인
        if [[ "$status" == "ON" ]]; then
            local build_dir=""
            local module_git_url=""

            # 업데이트를 확인할 모듈 목록 (하드코딩)
            if [[ "$id" == "retroarch" ]]; then
                module_git_url="$RA_GIT_URL"
            elif [[ "$id" == "emulationstation" ]]; then
                module_git_url="$ES_GIT_URL"
            fi

            if [[ -n "$module_git_url" ]]; then
                build_dir="$INSTALL_BUILD_DIR/$(get_Git_Project_Dir_Name "$module_git_url")"
                if git_check_update "$build_dir"; then
                    final_status="ON (업데이트 가능)"
                fi
            fi
        fi

        # 원본과 동일한 형식으로 결과 출력
        printf "%s\0%s\0%s\0%s\0%s\0" "$id" "$desc" "$section" "$type" "$final_status"
    done
}
