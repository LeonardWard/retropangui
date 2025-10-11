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
    "lr-bluemsx"         # MSX 시리즈
    "lr-nestopia"        # NES
    "lr-snes9x"          # SNES
    "lr-pcsx-rearmed"    # PSX
    "lr-dosbox-pure"     # DOS (dosbox-pure)
    "lr-genesis-plus-gx" # MegaDrive/Genesis
    "lr-quasi88"         # PC-88
    # "lr-np2kai"          # PC-98
    # "lr-fbneo"           # FBNeo
    # "lr-beetle-pce"      # PC엔진/TurboGrafx-16
)

install_base_cores() {
    log_msg STEP "사용자 정의 코어 자동 설치를 시작합니다..."

    source "$MODULES_DIR/ext_retropie_core.sh"
    setup_env

    for core_id in "${BASE_CORE_MODULES[@]}"; do
        export md_build="$INSTALL_BUILD_DIR/core_build"
        export md_inst="$LIBRETRO_CORE_PATH"
        log_msg INFO "코어 처리 시작: $core_id"
        local core_script_path="$MODULES_DIR/retropie_setup/scriptmodules/libretrocores/$core_id.sh"
        if [[ ! -f "$core_script_path" ]]; then
            log_msg ERROR "코어 스크립트 파일을 찾을 수 없습니다: $core_script_path"
            continue
        fi

        # 1. 코어 스크립트를 source하여 변수와 함수를 로드합니다.
        # 이 시점에 rp_module_repo와 sources_core_id, build_core_id 함수 등이 정의됩니다.
        source "$core_script_path"

        # 2. 소스 다운로드
        log_msg DEBUG "소스 다운로드 실행 시작"
        local build_dir="${md_build}/${rp_module_id}"
        if [[ -n "$rp_module_repo" ]]; then
            local repo_parts=($rp_module_repo)
            local repo_url="${repo_parts[1]}"
            log_msg INFO "$core_id 소스 다운로드를 시작합니다..."
            git_Pull_Or_Clone "$repo_url" "$build_dir" || {
                log_msg ERROR "$core_id 소스 다운로드 실패."
                continue
            }
        else
            log_msg ERROR "rp_module_repo가 정의되지 않았습니다: $core_id"
            continue
        fi
        log_msg DEBUG "소스 다운로드 실행 완료"

        # 3. 빌드
        if [[ -d "$build_dir" ]]; then
            cd "$build_dir"
            log_msg INFO "$core_id 빌드를 시작합니다... (in $(pwd))"
            log_msg DEBUG "build_${core_id} 실행 시작"

            if declare -f "build_$core_id" > /dev/null; then
                local build_status=0
                build_$core_id
                build_status=$?

                if [[ $build_status -ne 0 ]]; then
                    log_msg ERROR "build_${core_id} 실행 중 오류 발생 (Exit Code: $build_status)"
                    continue
                fi
            fi

            log_msg DEBUG "build_${core_id} 실행 완료"
            log_msg INFO "빌드 완료."
            log_msg INFO "파일 목록 출력"
            log_msg INFO "$(pwd)"
            log_msg INFO "$(ls -l)"
            cd - >/dev/null
        else
            log_msg ERROR "빌드 디렉토리를 찾을 수 없습니다: $build_dir"
            continue
        fi

        # 4. 설치
        log_msg INFO "$core_id 설치를 시작합니다..."
        log_msg DEBUG "install_${core_id} 실행 시작"
        if declare -f "install_$core_id" > /dev/null; then
            install_$core_id
        fi
        log_msg DEBUG "install_${core_id} 실행 완료"

        # 이제 채워진 md_ret_files 배열을 사용하여 파일을 복사합니다.
        log_msg DEBUG "installLibretroCore 실행 시작"
        local install_dest_dir
        install_dest_dir="$(get_Install_Path "$core_script_path")"
        installLibretroCore "$build_dir" "$core_id" "$install_dest_dir"
        log_msg DEBUG "installLibretroCore 실행 완료"

        # 5. 설정
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
                continue
            fi
        fi
        log_msg DEBUG "configure_${core_id} 실행 완료"
        log_msg SUCCESS "$core_id 코어 처리 완료."
    done
}

install_base_cores