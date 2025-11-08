#!/usr/bin/env bash
#
# 파일명: loader.sh (이전: ext_retropie_core.sh)
# RetroPangui Module: RetroPie 호환 레이어 통합 로더
#
# RetroPie-Setup 스크립트와의 호환성을 위해 필요한 환경 변수 파일들을 모읍니다.
# ===============================================

source "$MODULES_DIR/compat/env.sh"
source "$MODULES_DIR/compat/utils.sh"
source "$MODULES_DIR/compat/registry.sh"
source "$MODULES_DIR/compat/build.sh"
source "$MODULES_DIR/compat/packages.sh"
