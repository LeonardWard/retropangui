#!/usr/bin/env bash
#
# 파일명: base_cores.sh
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
    "lr-mupen64plus"            # NINTENDO 64
    "lr-np2kai"                 # PC-98
)

# packages.sh의 install_module 함수를 소싱합니다.
source_install_module() {
    local packages_script="$MODULES_DIR/lib/packages.sh"
    if [[ ! -f "$packages_script" ]]; then
        log_msg ERROR "packages.sh를 찾을 수 없습니다: $packages_script"
        return 1
    fi
    source "$packages_script"
    log_msg DEBUG "packages.sh 소싱 완료 (install_module 함수 로드됨)"
    return 0
}

# 메인 코어 설치 함수
install_base_cores() {
    log_msg STEP "main 코어 자동 설치를 시작합니다..."

    # packages.sh 소싱 (install_module 함수 사용 준비)
    if ! source_install_module; then
        log_msg ERROR "install_module 함수 로드 실패로 설치 중단."
        return 1
    fi

    # 각 코어를 install_module 함수로 처리
    for core_id in "${BASE_CORE_MODULES[@]}"; do
        # 이미 설치되어 있는지 확인
        if is_libretro_core_installed "$core_id"; then
            log_msg INFO "코어 $core_id가 이미 설치되어 있습니다. 설치를 건너뜁니다."
            continue
        fi

        log_msg INFO "코어 설치 시작: $core_id"

        # install_module 함수 호출 (libretrocores 타입)
        if ! install_module "$core_id" "libretrocores"; then
            log_msg ERROR "코어 $core_id 설치 실패로 전체 설치 중단."
            return 1
        fi

        log_msg SUCCESS "$core_id 코어 설치 완료."
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
