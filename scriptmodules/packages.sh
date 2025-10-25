#!/usr/bin/env bash

# Minimal packages.sh for Retro Pangui

# depends_on: 필요한 OS 패키지 설치 보장
depends_on() {
    for pkg in "$@"; do
        if ! dpkg -s "$pkg" &> /dev/null; then
            echo "[INFO] 패키지 $pkg 설치 중..."
            sudo apt-get install -y "$pkg"
        else
            echo "[INFO] 패키지 $pkg 이미 설치됨."
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
    echo "[INFO] 에뮬레이터 등록: $id for $sys ($so_path)"
}

# addSystem: 시스템에 등록(예시)
addSystem() {
    local sys="$1"
    # 시스템별 등록 구체적 구현 필요
    echo "[INFO] 시스템 등록: $sys"
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

    log_msg STEP "$module_id ($module_type) 모듈 설치를 시작합니다..."

    local script_path="$MODULES_DIR/retropie_setup/scriptmodules/$module_type/$module_id.sh"
    if [[ ! -f "$script_path" ]]; then
        log_msg ERROR "모듈 스크립트 파일을 찾을 수 없습니다: $script_path"
        return 1
    fi

    export md_ret_files=()

    source "$script_path"

    local funcs=("depends" "sources" "build" "install" "configure")
    for func_name in "${funcs[@]}"; do
        log_msg INFO "[$module_id] '${func_name}' 단계를 실행합니다..."
        local status=0

        case "$func_name" in
            depends)
                # depends는 무조건 성공 처리 (공식 RetroPie-Setup 방식)
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
                        "${func_name}_$module_id" || status=$?
                        popd >/dev/null
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

        if [[ $status -ne 0 ]]; then
            log_msg ERROR "[$module_id] '${func_name}' 단계 실행 중 오류가 발생했습니다 (Exit Code: $status)."
            return 1
        fi
    done

    if [[ "$module_type" == "libretrocores" ]]; then
        log_msg INFO "[$module_id] 최종 코어 파일 복사를 실행합니다..."
        local actual_source_dir="$md_build"
        if [[ ${#md_ret_files[@]} -eq 0 ]]; then
            log_msg ERROR "[$module_id] 'install' 단계에서 'md_ret_files'가 설정되지 않았습니다. 설치할 파일이 없습니다."
            return 1
        fi
        installLibretroCore "$actual_source_dir" "$module_id" "$md_inst" || return 1

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
        
        # 파일명만 추출 (basename)
        local so_filename="$(basename "$installed_so_file")"
        
        echo "$so_filename" | sudo tee "$md_inst/.installed_so_name" >/dev/null
        sudo chown "$__user":"$__user" "$md_inst/.installed_so_name"
        log_msg INFO "[$module_id] 설치된 코어 메타데이터 파일 생성: $md_inst/.installed_so_name -> $so_filename"
    fi

    log_msg SUCCESS "$module_id 모듈 설치 및 설정이 완료되었습니다."
    return 0
}

