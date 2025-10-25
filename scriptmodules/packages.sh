#!/usr/bin/env bash

# Minimal packages.sh for Retro Pangui

# isPlatform: 시스템 아키/플랫폼을 체크
isPlatform() {
    case "$1" in
        "x86") [[ "$(uname -m)" =~ "x86_64|i686|i386" ]];;
        "arm") [[ "$(uname -m)" =~ "arm"|"aarch64" ]];;
        *) return 1;;
    esac
}

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

    # --- 환경 설정 ---
    source "$MODULES_DIR/ext_retropie_core.sh"
    setup_env

    export md_id="$module_id"
    export md_build="$INSTALL_BUILD_DIR/$module_id"

    # 모듈 타입에 따라 설치 경로(md_inst)를 다르게 설정
    case "$module_type" in
        libretrocores)
            export md_inst="$LIBRETRO_CORE_PATH"
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

    # --- 스크립트 로드 ---
    local script_path="$MODULES_DIR/retropie_setup/scriptmodules/$module_type/$module_id.sh"
    if [[ ! -f "$script_path" ]]; then
        log_msg ERROR "모듈 스크립트 파일을 찾을 수 없습니다: $script_path"
        return 1
    fi
    source "$script_path"

    # --- 의존성, 소스, 빌드, 설치, 설정 함수들을 순차적으로 실행 ---
    local funcs=("depends" "sources" "build" "install" "configure")
    for func_name in "${funcs[@]}"; do
        if declare -f "${func_name}_$module_id" > /dev/null; then
            log_msg INFO "[$module_id] '${func_name}' 단계를 실행합니다..."
            # 각 단계를 실행하기 전에 빌드 디렉토리로 이동 (필요한 경우)
            if [[ "$func_name" == "build" || "$func_name" == "install" ]]; then
                cd "$md_build" || return 1
            fi

            "${func_name}_$module_id"
            local status=$?

            if [[ "$func_name" == "build" || "$func_name" == "install" ]]; then
                cd - >/dev/null
            fi

            if [[ $status -ne 0 ]]; then
                log_msg ERROR "[$module_id] '${func_name}' 단계 실행 중 오류가 발생했습니다 (Exit Code: $status)."
                return 1
            fi
        fi
    done

    # Libretro 코어의 경우, 최종 .so 파일 복사 단계를 추가로 실행
    if [[ "$module_type" == "libretrocores" ]]; then
        log_msg INFO "[$module_id] 최종 코어 파일 복사를 실행합니다..."
        installLibretroCore "$md_build" "$module_id" "$md_inst"
    fi

    log_msg SUCCESS "$module_id 모듈 설치 및 설정이 완료되었습니다."
    return 0
}
