#!/usr/bin/env bash

# Minimal packages.sh for Retro Pangui

# depends_on: 필요한 OS 패키지 설치 보장
depends_on() {
    for pkg in "$@"; do
        if ! dpkg -s "$pkg" &> /dev/null; then
            log_msg INFO "패키지 $pkg 설치 중..."
            sudo apt-get install -y "$pkg"
        else
            log_msg INFO "패키지 $pkg 이미 설치됨."
        fi
    done
}

# rpSwap: 빌드 스왑 공간(필요시)
rpSwap() {
    # 실제 swapon/off 등 구현 필요시 확장, 현재는 noop
    true
}

# mkRomDir: ROM 디렉토리 생성(예시)
mkRomDir() {
    local sys="$1"
    local dir="${USER_ROMS_PATH:-$HOME/roms}/$sys"
    mkdir -p "$dir"
}

# addEmulator: 에뮬레이터 시스템에 등록(예시)
addEmulator() {
    local def="$1"
    local id="$2"
    local sys="$3"
    local so_path="$4"
    # 실제 등록 행위는 UI/DB와 연동시 별도 구현 필요
    log_msg INFO "에뮬레이터 등록: $id for $sys ($so_path)"
}

# addSystem: 시스템에 등록(예시)
addSystem() {
    local sys="$1"
    # 시스템별 등록 구체적 구현 필요
    log_msg INFO "시스템 등록: $sys"
}

# 개별 모듈(코어, 에뮬레이터, 포트)을 소스에서 빌드하고 설치하는 범용 함수
# 사용법: install_module "모듈id" "모듈타입"
function install_module() {
    local module_id="$1"
    local module_type="$2"

    if [[ -z "$module_id" || -z "$module_type" ]]; then
        log_msg ERROR "install_module: Module ID 또는 Type이 제공되지 않았습니다."
        return 1
    fi

    source "$MODULES_DIR/ext_retropie_core.sh"
    setup_env

    export md_id="$module_id"
    export md_build="$INSTALL_BUILD_DIR/$module_id"

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

    # md_data: 모듈의 데이터 파일(패치 등)이 있는 디렉토리
    export md_data="$MODULES_DIR/retropie_setup/scriptmodules/$module_type/$module_id"

    log_msg INFO "Setting md_data=$md_data"

    log_msg STEP "$module_id ($module_type) 모듈 설치를 시작합니다..."

    local script_path="$MODULES_DIR/retropie_setup/scriptmodules/$module_type/$module_id.sh"
    if [[ ! -f "$script_path" ]]; then
        log_msg ERROR "모듈 스크립트 파일을 찾을 수 없습니다: $script_path"
        return 1
    fi

    export md_ret_files=()
    export md_ret_require=""

    source "$script_path"

    local funcs=("depends" "sources" "build" "install" "configure")
    for func_name in "${funcs[@]}"; do
        log_msg INFO "[$module_id] '${func_name}' 단계를 실행합니다..."
        local status=0

        case "$func_name" in
            depends)
                if declare -f "${func_name}_$module_id" > /dev/null; then
                    "${func_name}_$module_id" || status=$?
                fi
                ;;
            sources)
                if [[ -d "$md_build" ]]; then
                    log_msg INFO "[$module_id] 빌드 디렉토리 '$md_build'를 정리합니다."
                    sudo rm -rf "$md_build" || { log_msg ERROR "[$module_id] 빌드 디렉토리 정리 실패."; status=1; }
                fi
                if [[ $status -eq 0 ]]; then
                    if declare -f "sources_$module_id" > /dev/null; then
                        sources_"$module_id" || status=$?
                    elif [[ -n "$rp_module_repo" ]]; then
                        git_Pull_Or_Clone "$rp_module_repo" "$md_build" || status=$?
                    else
                        log_msg WARN "[$module_id] 'sources' 함수 또는 'rp_module_repo'가 정의되지 않았습니다. 소스 다운로드 단계를 건너뜁니다."
                    fi
                fi
                ;;
            build|install)
                local actual_source_dir="$md_build"
                if [[ -d "$actual_source_dir" ]]; then
                    pushd "$actual_source_dir" >/dev/null || { log_msg ERROR "[$module_id] 디렉토리 '$actual_source_dir'로 이동 실패."; status=1; }
                    if [[ $status -eq 0 ]]; then
                        if declare -f "${func_name}_$module_id" > /dev/null; then
                            "${func_name}_$module_id" || status=$?
                        fi
                        popd >/dev/null

                        # install 단계 직후 libretrocore 파일 복사
                        if [[ "$func_name" == "install" && "$module_type" == "libretrocores" && $status -eq 0 ]]; then
                            log_msg INFO "[$module_id] 최종 코어 파일 복사를 실행합니다..."
                            if [[ ${#md_ret_files[@]} -eq 0 ]]; then
                                log_msg ERROR "[$module_id] 'install' 단계에서 'md_ret_files'가 설정되지 않았습니다. 설치할 파일이 없습니다."
                                status=1
                            else
                                installLibretroCore "$actual_source_dir" "$module_id" "$md_inst" || status=$?
                            fi
                        fi
                    fi
                else
                    log_msg ERROR "[$module_id] 소스 디렉토리 '$actual_source_dir'를 찾을 수 없습니다. '${func_name}' 단계 실패."
                    status=1
                fi
                ;;
            *)
                if declare -f "${func_name}_$module_id" > /dev/null; then
                    "${func_name}_$module_id" || status=$?
                fi
                ;;
        esac

        # 빌드 후 필수 파일 생성 여부 확인
        if [[ "$func_name" == "build" && $status -eq 0 && -n "$md_ret_require" ]]; then
            local required_file="${md_ret_require[0]}"
            local full_path

            # `case` 구문을 사용하여 절대/상대 경로를 명확하게 확인
            case "$required_file" in
                /*) # 절대 경로인 경우
                    full_path="$required_file"
                    ;;
                *)  # 상대 경로인 경우
                    full_path="$md_build/$required_file"
                    ;;
            esac

            if [[ ! -f "$full_path" ]]; then
                log_msg ERROR "[$module_id] 빌드 실패: 필수 파일 '$full_path'가 생성되지 않았습니다."
                status=1
            fi
        fi

        if [[ $status -ne 0 ]]; then
            log_msg ERROR "[$module_id] '${func_name}' 단계 실행 중 오류가 발생했습니다 (Exit Code: $status)."
            return 1
        fi
    done

    # libretrocore의 경우 es_systems.xml 업데이트 및 메타데이터 생성
    if [[ "$module_type" == "libretrocores" ]]; then
        local installed_so_file=""
        for f in "${md_ret_files[@]}"; do
            if [[ "$f" == *.so ]]; then
                installed_so_file="$f"
                break
            fi
        done

        if [[ -z "$installed_so_file" ]]; then
            log_msg ERROR "[$module_id] md_ret_files에 .so 파일이 없습니다: ${md_ret_files[*]}"
            return 1
        fi

        local so_filename="$(basename "$installed_so_file")"

        echo "$so_filename" | sudo tee "$md_inst/.installed_so_name" >/dev/null
        sudo chown "$__user":"$__user" "$md_inst/.installed_so_name"
        log_msg INFO "[$module_id] 설치된 코어 메타데이터 파일 생성: $md_inst/.installed_so_name -> $so_filename"

        log_msg INFO "[$module_id] es_systems.xml 업데이트를 시작합니다..."
        update_es_systems_for_core "$module_id" "$so_filename"
    fi

    log_msg SUCCESS "$module_id 모듈 설치 및 설정이 완료되었습니다."
    return 0
}

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

    # es_systems_updater.sh 로드
    local updater_script="$MODULES_DIR/es_systems_updater.sh"
    if [[ ! -f "$updater_script" ]]; then
        log_msg WARN "[$module_id] es_systems_updater.sh를 찾을 수 없습니다. XML 업데이트 건너뜀."
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

    # emulator_priorities.conf에서 priority와 fullname 조회
    # config.sh에서 export된 MODULES_DIR 사용
    local priority_file="$MODULES_DIR/emulator_priorities.conf"
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

# 개별 모듈 제거 함수
# 사용법: remove_module "모듈id" "모듈타입"
function remove_module() {
    local module_id="$1"
    local module_type="$2"

    if [[ -z "$module_id" || -z "$module_type" ]]; then
        log_msg ERROR "remove_module: Module ID 또는 Type이 제공되지 않았습니다."
        return 1
    fi

    source "$MODULES_DIR/ext_retropie_core.sh"
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
                    source "$MODULES_DIR/es_systems_updater.sh"
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
