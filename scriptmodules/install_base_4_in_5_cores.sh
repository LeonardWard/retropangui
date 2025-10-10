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
    "lr-nestopia"        # NES
    # "lr-snes9x"          # SNES
    # "lr-pcsx-rearmed"    # PSX
    # "lr-dosbox-pure"     # DOS (dosbox-pure)
    # "lr-fbneo"           # FBNeo
    # "lr-genesis-plus-gx" # MegaDrive/Genesis
    # "lr-beetle-pce"      # PC엔진/TurboGrafx-16
    # "lr-quasi88"         # PC-88
    # "lr-np2kai"          # PC-98
    # "lr-bluemsx"         # MSX 시리즈
)

install_base_cores() {
    log_msg STEP "사용자 정의 코어 자동 설치를 시작합니다..."

    source "$MODULES_DIR/func_ext_retropie.sh"
    setup_env

    for core_id in "${BASE_CORE_MODULES[@]}"; do
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
        log_msg DEBUG "sources_${core_id} 실행 시작"
        set -x # 디버깅 시작
        if declare -f "sources_$core_id" > /dev/null; then
            log_msg INFO "$core_id 소스 다운로드를 시작합니다..."
            local sources_output
            local sources_status=0
            sources_output=$("sources_$core_id" 2>&1)
            sources_status=$?

            if [[ $sources_status -ne 0 ]]; then
                log_msg ERROR "sources_${core_id} 실행 중 오류 발생 (Exit Code: $sources_status). 상세 내용:\n$sources_output"
                false
            else
                true
            fi
        fi
        set +x # 디버깅 종료
        log_msg DEBUG "sources_${core_id} 실행 완료"

        # 3. 빌드
        # rp_module_id는 코어 스크립트에서 정의된 것을 사용합니다.
        local build_dir="${md_build}/${rp_module_id}"
        if [[ -d "$build_dir" ]]; then
            cd "$build_dir"
            log_msg INFO "$core_id 빌드를 시작합니다... (in $(pwd))"
            log_msg DEBUG "build_${core_id} 실행 시작"
            set -x # 디버깅 시작
            if declare -f "build_$core_id" > /dev/null; then
                local build_output
                local build_status=0
                build_output=$("build_$core_id" 2>&1)
                build_status=$?

                if [[ $build_status -ne 0 ]]; then
                    log_msg ERROR "build_${core_id} 실행 중 오류 발생 (Exit Code: $build_status). 상세 내용:\n$build_output"
                    false
                else
                    true
                fi
            fi
            set +x # 디버깅 종료
            log_msg DEBUG "build_${core_id} 실행 완료"
            # [추가] 빌드 직후 결과 확인을 위한 디버깅 코드
            log_msg INFO "빌드 완료. 파일 목록 출력 $(pwd):"
            ls -l

            # 4. 설치
            log_msg INFO "$core_id 설치를 시작합니다..."
            log_msg DEBUG "install_${core_id} 실행 시작"
            set -x # 디버깅 시작
            if declare -f "install_$core_id" > /dev/null; then
                "install_$core_id"
            fi
            set +x # 디버깅 종료
            log_msg DEBUG "install_${core_id} 실행 완료"
            # 이제 채워진 md_ret_files 배열을 사용하여 파일을 복사합니다.
            log_msg DEBUG "installLibretroCore 실행 시작"
            set -x # 디버깅 시작
            installLibretroCore "$build_dir" "$rp_module_id"
            set +x # 디버깅 종료
            log_msg DEBUG "installLibretroCore 실행 완료"

            cd - >/dev/null
        else
            log_msg ERROR "빌드 디렉토리를 찾을 수 없습니다: $build_dir"
            continue
        fi

        # 5. 설정
        # configure 함수가 $md_id 변수를 사용하므로, 여기서 설정해줍니다.
        export md_id="$core_id"
        log_msg DEBUG "Calling configure for $core_id. Current rp_module_id is: '$rp_module_id'"
        log_msg DEBUG "configure_${core_id} 실행 시작"
        set -x # 디버깅 시작
        if declare -f "configure_$core_id" > /dev/null; then
            log_msg INFO "$core_id 설정을 시작합니다..."
            local configure_output
            local configure_status=0
            # configure 함수의 stdout/stderr를 캡처
            configure_output=$("configure_$core_id" 2>&1)
            configure_status=$? # configure_$core_id의 종료 코드 저장

            if [[ $configure_status -ne 0 ]]; then
                log_msg ERROR "configure_${core_id} 실행 중 오류 발생 (Exit Code: $configure_status). 상세 내용:\n$configure_output"
                false # $?를 1로 설정하여 다음 if [[ $? -eq 0 ]]에서 실패로 판단하도록 함
            else
                true # $?를 0으로 설정하여 다음 if [[ $? -eq 0 ]]에서 성공으로 판단하도록 함
            fi
        fi
        set +x # 디버깅 종료
        log_msg DEBUG "configure_${core_id} 실행 완료"

        if [[ $? -eq 0 ]]; then
            log_msg SUCCESS "$core_id 코어 처리 완료."
        else
            log_msg ERROR "$core_id 코어 처리 중 오류 발생."
        fi
    done
}

install_base_cores
