#!/usr/bin/env bash
#
# 파일명: install_base_4_in_5_cores.sh
# Retro Pangui Module: libretro Core Installation (Base 4/5)
# 
# install_base_cores 함수를 정의합니다.
# 부연설명: 정의된 리스트에 따라 개별 코어 스크립트를 source하여 코어를 빌드/설치합니다.
# ===============================================

# 설치 대상 코어 목록
BASE_CORE_MODULES=(
    "lr-bluemsx"                # MSX 시리즈
    "lr-nestopia"               # NES
    "lr-fceumm"                 # FDS
    "lr-snes9x"                 # SNES
    "lr-pcsx-rearmed"           # PSX
    "lr-dosbox-pure"            # DOS (dosbox-pure)
    "lr-genesis-plus-gx"        # MegaDrive/Genesis
    "lr-quasi88"                # PC-88
    "lr-beetle-pce-fast"        # PC엔진/TurboGrafx-16
    "lr-beetle-supergrafx"      # PCE
    "lr-fbneo"                  # FBNeo
    # "lr-mupen64plus"            # NINTENDO 64
    # "lr-np2kai"                 # PC-98
)

# 환경 설정 함수
setup_environment() {
    source "$MODULES_DIR/ext_retropie_core.sh"
    setup_env
}

# 코어 스크립트 소스 로드 함수
load_core_script() {
    local core_id="$1"
    local core_script_path="$MODULES_DIR/retropie_setup/scriptmodules/libretrocores/$core_id.sh"
    if [[ ! -f "$core_script_path" ]]; then
        log_msg ERROR "코어 스크립트 파일을 찾을 수 없습니다: $core_script_path"
        return 1
    fi
    source "$core_script_path"
    return 0
}

# 코어 소스 다운로드 함수
download_core_source() {
    local core_id="$1"
    local build_dir="${md_build}/${rp_module_id}"
    if [[ -n "$rp_module_repo" ]]; then
        local repo_parts=($rp_module_repo)
        local repo_url="${repo_parts[1]}"
        log_msg INFO "$core_id 소스 다운로드를 시작합니다..."
        git_Pull_Or_Clone "$repo_url" "$build_dir" || {
            log_msg ERROR "$core_id 소스 다운로드 실패."
            return 1
        }
    else
        log_msg ERROR "rp_module_repo가 정의되지 않았습니다: $core_id"
        return 1
    fi
    log_msg DEBUG "소스 다운로드 실행 완료"
    return 0
}

# 코어 빌드 함수
build_core() {
    local core_id="$1"
    local build_dir="${md_build}/${rp_module_id}"
    if [[ -d "$build_dir" ]]; then
        cd "$build_dir"
        log_msg INFO "$core_id 빌드를 시작합니다... (in $(pwd))"
        log_msg DEBUG "build_${core_id} 실행 시작"

        if declare -f "build_$core_id" > /dev/null; then
            local build_status=0
            local original_md_build="$md_build"
            export md_build="$build_dir"

            build_$core_id
            build_status=$?

            export md_build="$original_md_build"

            if [[ $build_status -ne 0 ]]; then
                log_msg ERROR "build_${core_id} 실행 중 오류 발생 (Exit Code: $build_status)"
                cd - >/dev/null
                return 1
            fi

            # 추가: 빌드 결과 파일 확인 (md_ret_require가 설정된 경우)
            if [[ -n "$md_ret_require" && ! -f "$md_ret_require" ]]; then
                log_msg ERROR "빌드 결과 파일을 생성하지 못했습니다: $md_ret_require"
                cd - >/dev/null
                return 1
            fi
        fi

        log_msg DEBUG "build_${core_id} 실행 완료"
        log_msg INFO "빌드 완료."
        log_msg INFO "파일 목록 출력"
        log_msg INFO "$(pwd)"
        log_msg INFO "$(ls -l)"
        cd - >/dev/null
        return 0
    else
        log_msg ERROR "빌드 디렉토리를 찾을 수 없습니다: $build_dir"
        return 1
    fi
}

# 코어 설치 함수
install_core() {
    local core_id="$1"
    local build_dir="$2"
    log_msg INFO "$core_id 설치를 시작합니다..."
    log_msg DEBUG "install_${core_id} 실행 시작"
    if declare -f "install_$core_id" > /dev/null; then
        install_$core_id
    fi
    log_msg DEBUG "install_${core_id} 실행 완료"

    log_msg DEBUG "installLibretroCore 실행 시작"
    local install_dest_dir
    local core_script_path="$MODULES_DIR/retropie_setup/scriptmodules/libretrocores/$core_id.sh"
    install_dest_dir="$(get_Install_Path "$core_script_path")"
    installLibretroCore "$build_dir" "$core_id" "$install_dest_dir"
    log_msg DEBUG "installLibretroCore 실행 완료"
    return 0
}

# 코어 설정 함수
configure_core() {
    local core_id="$1"
    export md_id="$core_id"
    log_msg DEBUG "Calling configure for $core_id. Current rp_module_id is: '$rp_module_id'"
    log_msg DEBUG "configure_${core_id} 실행 시작"
    if declare -f "configure_$core_id" > /dev/null; then
        if [[ "$core_id" == "lr-bluemsx" ]]; then
            log_msg DEBUG "Debugging lr-bluemsx configure function:"
            log_msg DEBUG "  md_conf_root: '$md_conf_root'"
            log_msg DEBUG "  core_config (before iniConfig): '$md_conf_root/coleco/retroarch-core-options.cfg'"
        fi
        log_msg INFO "$core_id 설정을 시작합니다..."
        local configure_status=0
        configure_$core_id
        configure_status=$?

        if [[ $configure_status -ne 0 ]]; then
            log_msg ERROR "configure_${core_id} 실행 중 오류 발생 (Exit Code: $configure_status)"
            return 1
        fi
    fi
    log_msg DEBUG "configure_${core_id} 실행 완료"
    return 0
}

# 개별 코어 처리 함수
process_single_core() {
    local core_id="$1"
    export md_build="$INSTALL_BUILD_DIR/core_build"
    export md_inst="$LIBRETRO_CORE_PATH"
    log_msg INFO "코어 처리 시작: $core_id"

    if ! load_core_script "$core_id"; then
        log_msg ERROR "$core_id 코어 스크립트 로드 실패로 진행 중단."
        return 1
    fi

    if declare -f "depends_$core_id" > /dev/null; then
        depends_$core_id
    fi

    log_msg DEBUG "소스 다운로드 실행 시작"
    if ! download_core_source "$core_id"; then
        log_msg ERROR "$core_id 소스 다운로드 실패로 진행 중단."
        return 1
    fi

    if ! build_core "$core_id"; then
        log_msg ERROR "$core_id 빌드 실패로 진행 중단."
        return 1
    fi

    local build_dir="${md_build}/${rp_module_id}"
    if ! install_core "$core_id" "$build_dir"; then
        log_msg ERROR "$core_id 설치 실패로 진행 중단."
        return 1
    fi

    if ! configure_core "$core_id"; then
        log_msg ERROR "$core_id 설정 실패로 진행 중단."
        return 1
    fi

    log_msg SUCCESS "$core_id 코어 처리 완료."
    return 0
}

# 메인 코어 설치 함수
install_base_cores() {
    log_msg STEP "main 코어 자동 설치를 시작합니다..."

    setup_environment

    for core_id in "${BASE_CORE_MODULES[@]}"; do
        if ! process_single_core "$core_id"; then
            log_msg ERROR "코어 $core_id 처리 실패로 전체 설치 중단."
            return 1
        fi
    done

    log_msg SUCCESS "모든 base 코어 설치 완료."
}

# 이 스크립트가 직접 실행될 때만 install_base_cores 함수를 호출합니다.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    # 환경 변수 설정을 위해 메인 설정 스크립트를 source 합니다.
    # retropangui_setup.sh는 source될 때 main()을 실행하지 않으므로 안전합니다.
    source "$(dirname "${BASH_SOURCE[0]}")/../retropangui_setup.sh"
    install_base_cores "$@"
fi
