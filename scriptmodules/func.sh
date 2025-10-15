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

# runcommand.sh 스크립트를 생성하는 함수
create_runcommand_script() {
    local script_path="$USER_SYSTEM_PATH/runcommand.sh"
    log_msg INFO "runcommand.sh 스크립트를 생성합니다: $script_path"

    # heredoc의 EOF를 'EOF'로 감싸면 내부의 변수가 확장되지 않고 문자열 그대로 들어갑니다.
    sudo tee "$script_path" > /dev/null << 'EOF'
#!/usr/bin/env bash

# 이 스크립트의 위치를 기준으로 config.sh 경로를 찾습니다.
if [[ -f "/home/pangui/scripts/retropangui/scriptmodules/config.sh" ]]; then
    source "/home/pangui/scripts/retropangui/scriptmodules/config.sh"
else
    echo "FATAL: Cannot find config.sh" >&2
    exit 1
fi

# 인수 처리
SYSTEM_NAME="$3"
ROM_PATH="$4"

# 로그 파일 준비
RUN_LOG="$LOG_DIR/runcommand.log"

log() {
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

DEFAULT_EMU_ID=$(grep "^default\s*=" "$EMULATORS_CFG_PATH" | cut -d'=' -f2 | tr -d ' "')
log "기본 에뮬레이터 ID: $DEFAULT_EMU_ID"

if [[ -z "$DEFAULT_EMU_ID" ]]; then
    log "오류: emulators.cfg에 기본 에뮬레이터(default)가 설정되지 않았습니다."
    exit 1
fi

LAUNCH_COMMAND=$(grep "^$DEFAULT_EMU_ID\s*=" "$EMULATORS_CFG_PATH" | sed -n 's/^[^=]*=\s*\"\([^\"]*\)\".*/\1/p')
log "추출된 실행 명령어: $LAUNCH_COMMAND"

if [[ -z "$LAUNCH_COMMAND" ]]; then
    log "오류: 에뮬레이터 ID '$DEFAULT_EMU_ID'에 대한 실행 명령어를 찾을 수 없습니다."
    exit 1
fi

FINAL_COMMAND="${LAUNCH_COMMAND//%ROM%/\"$ROM_PATH\"}"
log "최종 실행 명령어: $FINAL_COMMAND"

eval "$FINAL_COMMAND"

log "--- Runcommand 종료 ---"
EOF

    # 스크립트 소유자 및 실행 권한 설정
    sudo chown "$__user":"$__user" "$script_path"
    sudo chmod +x "$script_path"
    log_msg SUCCESS "runcommand.sh 생성 및 실행 권한 설정 완료."
}

# RetroArch 구성요소(에셋, 설정 등)를 Git에서 클론/설치하는 함수
# 사용법: install_ra_component "component_name" "git_url" "target_dir"
install_ra_component() {
    local component_name="$1"
    local git_url="$2"
    local target_dir="$3"

    log_msg STEP "RetroArch $component_name 소스 클론 및 설치 시작..."

    if [[ -z "$git_url" || -z "$target_dir" ]]; then
        log_msg ERROR "$component_name 설치 실패: URL 또는 대상 디렉터리가 비어있습니다."
        return 1
    fi

    local ext_folder="$(get_Git_Project_Dir_Name "$git_url")"
    local build_dir="$INSTALL_BUILD_DIR/$ext_folder"
    log_msg INFO "ℹ️ $component_name 프로젝트 이름: $ext_folder"
    log_msg INFO "ℹ️ $component_name 빌드 디렉토리: $build_dir"

    log_msg INFO "$component_name 저장소($git_url) 클론 또는 pull 중..."
    git_Pull_Or_Clone "$git_url" "$build_dir" || return 1

    log_msg INFO "$component_name 설치 중 (대상: $target_dir)..."
    sudo mkdir -p "$target_dir"
    # rsync를 사용하여 원본의 내용을 대상 디렉터리로 복사합니다.
    # --delete 옵션은 원본에 없는 파일은 대상에서 삭제합니다.
    sudo rsync -a --delete "$build_dir/" "$target_dir/" || {
        log_msg ERROR "$component_name 설치 실패 (rsync 오류)."
        return 1
    }

    sudo chown -R "$__user":"$__user" "$target_dir"
    log_msg SUCCESS "RetroArch $component_name 설치 완료: $target_dir"
    return 0
}
