#!/usr/bin/env bash
#
# 파일명: func.sh
# 공용 기능 함수 모음, 사용자 정보 가져오기 함수
# 우선순위: $__user (core.sh에서 설정) > SUDO_USER > 현재 사용자
# ===============================================

get_effective_user() {
    if [[ -n "$__user" && "$__user" != "root" ]]; then
        echo "$__user"
    elif [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
        echo "$SUDO_USER"
    else
        # root라면 환경에서 가장 최근의 실제 일반 사용자를 반환
        users=$(who | awk '{print $1}' | grep -v '^root$' | sort | uniq)
        if [[ -n "$users" ]]; then
            echo "$users" | head -n 1
        else
            echo ""
        fi
    fi
}

# 디렉토리 생성 및 유효 사용자에게 소유권 설정 (재사용 가능한 함수)
set_dir_ownership_and_permissions() {
    local dir_path="$1"
    local target_user="$(get_effective_user)"

    if [[ -z "$target_user" ]]; then
        log_msg WARN "유효 사용자 이름 결정 실패. 'root'로 설정합니다."
        target_user="root"
    fi

    # 디렉토리 생성 및 소유권 설정 (권한 문제 방지)
    sudo mkdir -p "$dir_path" || { log_msg ERROR "디렉토리 생성 실패: $dir_path"; return 1; }
    sudo chown -R "$target_user":"$target_user" "$dir_path" || { log_msg ERROR "소유권 설정 실패: $dir_path"; return 1; }

    # 호출하는 함수에서 파일 소유권 설정을 위해 target_user를 반환 (출력)
    echo "$target_user"
    return 0
}

# git 저장소 URL에서 프로젝트(폴더)명 추출 함수
get_Git_Project_Dir_Name() {
    local url="$1"
    local name="$(basename "$url")"
    # .git 확장자 제거
    name="${name%.git}"
    echo "$name"
}

# 정확한 저장소 정보 파싱 및 git clone 동작
git_Pull_Or_Clone() {
    local repo_url="$1"
    local dest_dir="$2"
    shift 2
    if [ -d "$dest_dir/.git" ]; then
        cd "$dest_dir"
        git pull --ff-only
    else
        git clone "$@" "$repo_url" "$dest_dir"
    fi
}

# .sh 설정 파일의 변수 값을 변경하는 함수
# 사용법: config_set "KEY" "new_value" "/path/to/config.sh"
config_set() {
    local key="$1"
    local value="$2"
    local file="$3"

    # sed에서 사용할 수 있도록 value의 특수문자를 이스케이프 처리
    local escaped_value=$(printf '%s\n' "$value" | sed -e 's/[&/]/\\&/g')

    # 파일에 키가 존재하는지 확인하고 값을 변경
    if grep -q "^${key}=" "$file"; then
        sudo sed -i "s/^${key}=.*/${key}=\"${escaped_value}\"" "$file"
    elif grep -q "^#${key}=" "$file"; then
        sudo sed -i "s/^#${key}=.*/${key}=\"${escaped_value}\"" "$file"
    else
        echo "${key}=\"${escaped_value}\"" | sudo tee -a "$file" > /dev/null
    fi
}

# systemlist.csv를 기반으로 es_systems.cfg를 생성하는 함수 (v7, 최종 수정)
generate_es_systems_cfg_from_csv() {
    local src_csv="$1"
    local dest_cfg="$2"

    # 필요한 전역 변수 확인
    local roms_path="${USER_ROMS_PATH}"
    local runcommand_path="$USER_SYSTEM_PATH/runcommand.sh"

    if [[ ! -f "$src_csv" ]]; then
        log_msg ERROR "CSV 소스 파일을 찾을 수 없습니다: $src_csv"
        return 1
    fi

    log_msg INFO "es_systems.cfg 생성을 시작합니다 (runcommand 방식)..."
    sudo rm -f "$dest_cfg"

    echo "<systemList>" | sudo tee "$dest_cfg" > /dev/null

    # 1단계: awk로 CSV를 파싱하여 필요한 데이터만 | 문자로 구분하여 출력
    local parsed_data=$(awk -F, ' 
        NR==1 {
            for (i=1; i<=NF; i++) { gsub(/\r/, "", $i); col_map[$i] = i; rev_col_map[i] = $i; }
            next;
        }
        {
            best_core_name = "";
            lowest_prio = 100;

            for (i=1; i<=NF; i++) {
                header = rev_col_map[i];
                if (header ~ /emulatorList.*libretro.*_core_.*_priority/ && $i != "" && $i < lowest_prio) {
                    lowest_prio = $i;
                    name_header = header;
                    gsub("_priority", "_name", name_header);
                    best_core_name = $(col_map[name_header]);
                }
            }

            if (best_core_name == "") {
                lowest_prio = 100;
                for (i=1; i<=NF; i++) {
                    header = rev_col_map[i];
                    if (header ~ /_core_.*_priority/ && $i != "" && $i < lowest_prio) {
                        lowest_prio = $i;
                        name_header = header;
                        gsub("_priority", "_name", name_header);
                        best_core_name = $(col_map[name_header]);
                    }
                }
            }
            
            core_name = best_core_name;
            if (core_name == "") { next; }

            name = $(col_map["name"]);
            fullname = $(col_map["fullname"]);
            path = $(col_map["descriptor_1_path"]);
            theme = $(col_map["descriptor_1_theme"]);
            extensions = $(col_map["descriptor_1_extensions"]);
            
            printf "%s|%s|%s|%s|%s|%s\n", name, fullname, path, theme, extensions, core_name;
        }
    ' "$src_csv")

    # 2단계: 파싱된 데이터를 한 줄씩 읽어 XML 블록 생성
    echo "$parsed_data" | while IFS='|' read -r name fullname path theme extensions core_name; do
        if [[ -z "$name" ]]; then continue; fi
        final_path=$(echo "$path" | sed "s|%ROOT%|$roms_path|")
        command="$runcommand_path 0 _SYS_ $name %ROM%"

        cat << EOF | sudo tee -a "$dest_cfg" > /dev/null
 <system>
    <name>$name</name>
    <fullname>$fullname</fullname>
    <path>$final_path</path>
    <extension>$extensions</extension>
    <command>$command</command>
    <platform>$name</platform>
    <theme>$theme</theme>
 </system>
EOF
    done

    echo "</systemList>" | sudo tee -a "$dest_cfg" > /dev/null

    sudo chown "$__user":"$__user" "$dest_cfg"
    log_msg SUCCESS "es_systems.cfg 생성 완료: $dest_cfg"
}

create_runcommand_script() {
    local script_path="$USER_SYSTEM_PATH/runcommand.sh"
    log_msg INFO "runcommand.sh 스크립트를 생성합니다: $script_path"

    # heredoc의 EOF를 'EOF'로 감싸지 않았으므로, 내부 변수는 반드시 이스케이프(\$) 처리해야 합니다.
    sudo tee "$script_path" > /dev/null << 'EOF'
#!/usr/bin/env bash

# 파일명: runcommand.sh 
# --- [1] 환경 설정 로드 ---
# runcommand.sh는 독립 실행을 위해 runcommand_config.sh에서 모든 경로 변수를 로드해야 합니다.
SOURCE_PATH="$(dirname "${BASH_SOURCE[0]}")/runcommand_config.sh"
source "$SOURCE_PATH" || {
    # 설정 파일 로드 실패 시, 최소한 /tmp에 오류를 기록하고 종료합니다.
    # 이 로그는 runcommand_config.sh 로드 전에 실행되므로, 경로 정의 오류를 잡아낼 수 있습니다.
    echo "$(date +'%Y-%m-%d %H:%M:%S') - 치명적 오류: 설정 파일 로드 실패. ($SOURCE_PATH) 파일을 찾을 수 없거나 권한 문제가 있습니다." > /tmp/runcommand_fatal.log
    exit 1
}
# --------------------------

# 인수 처리
SYSTEM_NAME="$3"
ROM_PATH="$4"

# 로그 파일 준비
# USER_LOGS_PATH는 runcommand_config.sh를 통해 로드됩니다.
RUN_LOG="$USER_LOGS_PATH/runcommand.log"

log() {
    # 로그 디렉토리가 존재하는지 확인하고 없으면 생성합니다. (쓰기 권한 문제 방지)
    mkdir -p "$(dirname "$RUN_LOG")" 2>/dev/null
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$RUN_LOG"
}

log "--- Runcommand 시작 ---"
log "시스템: $SYSTEM_NAME"
log "롬 경로: $ROM_PATH"

EMULATORS_CFG_PATH="$USER_CONFIG_PATH/cores/$SYSTEM_NAME/emulators.cfg"
log "emulators.cfg 경로: $EMULATORS_CFG_PATH"

if [[ ! -f "$EMULATORS_CFG_PATH" ]]; then
    log "오류: emulators.cfg 파일을 찾을 수 없습니다."
    exit 1
fi

# 1. 기본 에뮬레이터 ID 추출
DEFAULT_EMU_ID=$(grep "^default\s*=" "$EMULATORS_CFG_PATH" | cut -d'=' -f2 | tr -d ' \"')
log "기본 에뮬레이터 ID: $DEFAULT_EMU_ID"


if [[ -z "$DEFAULT_EMU_ID" ]]; then
    log "오류: emulators.cfg에 기본 에뮬레이터(default)가 설정되지 않았습니다."
    exit 1
fi

# 2. LAUNCH_COMMAND 추출 (sed로 = 뒤 "값"만 추출)
LAUNCH_COMMAND=$(grep "^$DEFAULT_EMU_ID\s*=" "$EMULATORS_CFG_PATH" | sed 's/^[^=]*= *\("[^"]*"\).*$/\1/' | sed 's/^"\(.*\)"$/\1/')
log "추출된 실행 명령어: $LAUNCH_COMMAND"

if [[ -z "$LAUNCH_COMMAND" ]]; then
    log "오류: 에뮬레이터 ID '$DEFAULT_EMU_ID'에 대한 실행 명령어를 찾을 수 없습니다."
    exit 1
fi

# 3. FINAL_COMMAND 생성 (롬 경로를 쌍따옴표로 감싸 치환)
# %ROM%을 "$ROM_PATH"로 치환하여 공백 포함 경로를 안전하게 처리
FINAL_COMMAND="${LAUNCH_COMMAND//\%ROM\%/\"$ROM_PATH\"}"
log "최종 실행 명령어: $FINAL_COMMAND"

# 4. 명령어 실행 (foreground로 실행하여 ES가 에뮬 종료 대기)
eval "$FINAL_COMMAND"

log "--- Runcommand 종료 ---"
EOF

    # 스크립트 소유자 및 실행 권한 설정
    sudo chown "$__user":"$__user" "$script_path"
    sudo chmod +x "$script_path"
    log_msg SUCCESS "runcommand.sh 생성 및 실행 권한 설정 완료."
}

# runcommand_config.sh 스크립트를 생성하는 함수
# 이 함수는 config.sh에서 이미 정의된 환경 변수들을 캡처하여 하드코딩된 설정 파일을 만듭니다.
create_runcommand_config_script() {
    local project_root="$1"
    # USER_SYSTEM_PATH는 config.sh에서 이미 설정되었으므로 바로 사용합니다.
    local script_path="$USER_SYSTEM_PATH/runcommand_config.sh" 
    log_msg INFO "runcommand_config.sh 스크립트를 생성합니다: $script_path"

    # --- [1] 변수 사전 계산 제거: config.sh에서 설정된 환경 변수를 직접 사용합니다. ---
    # local effective_user="$(get_effective_user)"
    # ... 불필요한 재계산 로직 제거 ...
    # --------------------------------------------------------------------------------

    sudo tee "$script_path" > /dev/null << EOF
#!/usr/bin/env bash

# 파일명: runcommand_config.sh
# This file contains configuration variables specifically for runcommand.sh
# It is designed to provide hardcoded, persistent path variables.
# It is generated by create_runcommand_config_script() in func.sh using the variables
# exported by the main config.sh script during installation.

# --- [1] Project Root and Modules Directory (하드코딩 - 환경 변수 사용) ---
export RETROPANGUI_PROJECT_ROOT="${project_root}"
export RETROPANGUI_MODULES_DIR="${RETROPANGUI_PROJECT_ROOT}/scriptmodules"

# --- [2] 사용자 및 홈 디렉토리 설정 (하드코딩 - 환경 변수 사용) ---
export __user="${__user}"
export USER_HOME="${USER_HOME}"

# --- [3] 사용자별 경로 설정 (USER_HOME 기반 - 하드코딩 - 환경 변수 사용) ---
export USER_SHARE_PATH="${USER_SHARE_PATH}"
export USER_SYSTEM_PATH="${USER_SYSTEM_PATH}"
export USER_CONFIG_PATH="${USER_CONFIG_PATH}"
export USER_LOGS_PATH="${USER_LOGS_PATH}"
EOF

    sudo chown "$__user":"$__user" "$script_path"
    sudo chmod +x "$script_path"
    log_msg SUCCESS "runcommand_config.sh 생성 및 실행 권한 설정 완료."
}


# RetroArch 구성요소(에셋, 설정 등)를 Git에서 클론/설치하는 함수
# 사용법: install_ra_component "component_name" "git_url" "target_dir"
install_ra_component() {
    local component_name="$1"
    local git_url="$2"
    local target_dir="$3"
    local subdir="$(basename "$target_dir")"

    log_msg STEP "RetroArch $component_name 소스 클론 및 설치 시작..."

    if [[ -z "$git_url" || -z "$target_dir" ]]; then
        log_msg ERROR "$component_name 설치 실패: URL 또는 대상 디렉터리가 비어있습니다."
        return 1
    fi

    local ext_folder="$(get_Git_Project_Dir_Name "$git_url")"
    local build_dir="$INSTALL_BUILD_DIR/$ext_folder"
    log_msg INFO "ℹ️ $component_name 프로젝트 이름: $ext_folder"
    log_msg INFO "ℹ️ $component_name 빌드 디렉터리: $build_dir"

    log_msg INFO "$component_name 저장소($git_url) 클론 또는 pull 중..."
    git_Pull_Or_Clone "$git_url" "$build_dir" || return 1

    log_msg INFO "$component_name 빌드 및 설치 중 (대상: $target_dir)..."
    cd "$build_dir" || { log_msg ERROR "$component_name 설치 실패: 빌드 디렉터리로 이동할 수 없습니다."; return 1; }

    # If target_dir exists and is not empty, back it up
    if [ -d "$target_dir" ] && [ -n "$(ls -A "$target_dir")" ]; then
        sudo mv "$target_dir" "${target_dir}.backup_$(date +%Y%m%d_%H%M%S)"
    fi

    # Create target_dir if it doesn't exist
    sudo mkdir -p "$target_dir"

    log_msg INFO "$component_name: make install 실행 중 (대상: $target_dir)..."
    sudo make PREFIX="$USER_HOME" INSTALLDIR="$target_dir" install || {
        log_msg ERROR "$component_name 설치 실패 (make install 오류)."
        return 1
    }

    # 임시 설치 디렉터리 설정
    sudo chown -R "$__user":"$__user" "$target_dir"
    log_msg SUCCESS "RetroArch $component_name 설치 완료: $target_dir (/database/cht, /database/rdb 구조)"
    return 0
}

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

