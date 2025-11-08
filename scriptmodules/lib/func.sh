#!/usr/bin/env bash
#
# 파일명: func.sh
# 공용 기능 함수 로더
# 모든 분산된 유틸리티 함수들을 로드합니다.
# ===============================================

# 사용자 관련 함수
source "$MODULES_DIR/lib/user.sh"

# Git 관련 함수
source "$MODULES_DIR/lib/git.sh"

# 설정 파일 관련 함수
source "$MODULES_DIR/lib/config_utils.sh"

# RetroArch 관련 함수
source "$MODULES_DIR/lib/retroarch_utils.sh"

# 설치 상태 확인 함수
source "$MODULES_DIR/lib/check.sh"
