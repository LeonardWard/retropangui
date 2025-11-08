#!/usr/bin/env bash
#
# 파일명: install.sh
# 모듈 설치 함수
# ===============================================

# 개별 모듈(코어, 에뮬레이터, 포트)을 소스에서 빌드하고 설치하는 범용 함수
# 사용법: install_module "모듈id" "모듈타입"
function install_module() {
    local module_id="$1"
    local module_type="$2"

    if [[ -z "$module_id" || -z "$module_type" ]]; then
        log_msg ERROR "install_module: Module ID 또는 Type이 제공되지 않았습니다."
        return 1
    fi

    source "$MODULES_DIR/compat/loader.sh"
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
                # depends는 무조건 성공 처리 (공식 RetroPie-Setup 방식)
                # 조건부 명령어(isPlatform 등)가 실패해도 전체 설치는 계속 진행
                if declare -f "${func_name}_$module_id" > /dev/null; then
                    "${func_name}_$module_id" || true
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
            configure)
                # configure 전에 필요한 디렉토리 생성
                mkdir -p "$biosdir" 2>/dev/null || true

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
