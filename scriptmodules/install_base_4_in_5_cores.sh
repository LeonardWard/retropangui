#!/usr/bin/env bash
#
# 파일명: install_base_4_in_5_cores.sh
# Retro Pangui Module: Default Libretro Core Installation (Base 4/5)
# 이 스크립트는 기본 Libretro 코어 디렉토리를 설정하고 코어 설치를 위한 install_default_cores 함수를 정의합니다.
# ===============================================

#!/usr/bin/env bash
# Retro Pangui: Libretro Base Core Auto Installer

SCRIPT_DIR="$(dirname "$0")"
SCRIPT_DIR="$(cd "$SCRIPT_DIR" && pwd)"

# 환경변수/공통 툴 소스
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/helpers.sh"
source "$SCRIPT_DIR/inifuncs.sh"
source "$SCRIPT_DIR/packages.sh"
source "$SCRIPT_DIR/func_ext_retropie.sh"
setup_env

# 자동 설치할 베이스 코어 리스트 (RetroPie 모듈명 기준)
BASE_CORE_MODULES=(
    # "lr-nestopia"        # NES
    # "lr-snes9x"          # SNES
    # "lr-pcsx-rearmed"    # PSX
    # "lr-dosbox-pure"     # DOS (dosbox-pure)
    # "lr-fbneo"           # FBNeo
    # "lr-genesis-plus-gx" # MegaDrive/Genesis
    # "lr-beetle-pce"      # PC엔진/TurboGrafx-16
    # "lr-quasi88"         # PC-88
    # "lr-np2kai"          # PC-98
    "lr-bluemsx"         # MSX 시리즈
)

install_base_cores() {
    local SUCCESS=1

    log_msg STEP "기본 코어 자동 설치를 시작합니다..."

    for CORE in "${BASE_CORE_MODULES[@]}"; do
        export rp_module_repo="${CORE_REPOS[$CORE]}"
        export md_build="/tmp/build"

        source "$SCRIPT_DIR/libretrocores/$CORE.sh" || {
            log_msg ERROR "$CORE 모듈 스크립트 로드 실패"
            SUCCESS=0
            continue
        }

        sources_$CORE

        # 반드시 cd로 현재 작업 디렉터리 확정
        cd "$md_build/${CORE}-libretro" || {
            log_msg ERROR "코어 빌드 폴더 진입 실패: $md_build/${CORE}-libretro"
            SUCCESS=0
            continue
        }
        echo "[INFO] 현재 dir: $(pwd)" # 디버그 확인

        build_$CORE
        installLibretroCore
        install_$CORE
        configure_$CORE
    done

}

# 반드시 함수 호출!
install_base_cores
