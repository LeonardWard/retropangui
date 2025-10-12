#!/usr/bin/env bash
#
# 파일명: env_ext_retropie.sh
# RetroPangui Module: RetroPie 호환 환경 변수 정의
#
# RetroPie-Setup 스크립트와의 호환성을 위해 필요한 환경 변수들을 여기에 정의합니다.
# ===============================================

export __swapdir="$INSTALL_BUILD_DIR/swap"
export biosdir="$USER_BIOS_PATH"
export md_conf_root="$USER_CONFIG_PATH"