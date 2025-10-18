#!/usr/bin/env bash
#
# 파일명: install_base_5_in_5_setup_env.sh
# Retro Pangui Module: Environment Setup (Base 5/5)
# 
# 이 스크립트는 최종 환경 설정을 처리하는 
# setup_environment 함수를 정의합니다.
# ===============================================

setup_environment() {
    log_msg STEP "Retro Pangui 환경 설정 시작..."

    # # 복사 직전 기존 파일 백업
    # backup_if_exists "$RA_CONFIG_DIR/retroarch.cfg"
    # backup_if_exists "$ES_CONFIG_DIR/es_systems.cfg"

    # # 실패 시 안내 (에러 로그 경로 안내)
    # if [ $? -ne 0 ]; then
    #     log_msg ERROR "에러 발생: 자세한 내용은 $LOG_DIR 또는 $USER_LOGS_PATH 를 확인하세요."
    #     exit 1
    # fi

    # # TEMP_DIR, USER_SHARE_PATH, INSTALL_DIR, RA_CONFIG_DIR, ES_CONFIG_DIR, RECALBOX_GIT_URL 
    # # 등은 config.sh에서 정의됨
    # local CONFIG_CLONE_DIR="$TEMP_DIR/recalbox-config"
    
    # # 설치 명령을 실행한 사용자의 UID를 가져와 소유권 설정에 사용합니다.
    # local __user=$(stat -c '%U' "$TEMP_DIR")
    
    # # 핵심 디렉토리 생성 및 권한 설정
    # log_msg INFO "핵심 설치 디렉토리($INSTALL_ROOT_DIR, $LOG_DIR) 생성 및 권한 설정 중..."
    # sudo mkdir -p "$INSTALL_ROOT_DIR" "$LOG_DIR" || return 1
    
    # log_msg INFO "사용자 공유 경로($USER_SHARE_PATH) 생성 및 권한 설정 중..."
    # # 이 공유 경로는 ES의 롬 경로로 사용됩니다.
    # sudo mkdir -p "$USER_SHARE_PATH" || return 1
    
    # # 설치된 바이너리 및 사용자 공유 폴더의 소유자를 원래의 사용자로 변경
    # log_msg INFO "설치 경로 소유자를 사용자($__user)로 변경..."
    # # Share 폴더의 모든 콘텐츠는 사용자 소유여야 합니다.
    # sudo chown -R $__user:$__user "$USER_SHARE_PATH" || return 1
    
    # Recalbox의 테마 복사 (선택 사항, 기본 테마가 없는 경우를 대비)

    log_msg STEP "테마 소스 클론 시작..."
    local GIT_NAME="$(get_Git_Project_Dir_Name "$RECALBOX_THEMES_GIT_URL")"
    local CLONE_PATH="$INSTALL_BUILD_DIR/$GIT_NAME"
    log_msg INFO "ℹ️ 프로젝트 이름: $GIT_NAME"
    log_msg INFO "ℹ️ 빌드 디렉토리: $CLONE_PATH"

    # log_msg INFO "저장소($RECALBOX_THEMES_GIT_URL) 클론 또는 pull 중..."
    # git_Pull_Or_Clone "$RECALBOX_THEMES_GIT_URL" "$CLONE_PATH"
    
    # log_msg INFO "테마($CLONE_PATH/recalbox-themes/themes/recalbox-next) 복사 중..."
    # cp -r "$CLONE_PATH/themes/recalbox-next" "$USER_THEMES_PATH"
    # log_msg INFO "테마($USER_THEMES_PATH/recalbox-next) 복사 완료.."

    # runcommand.sh 스크립트 생성
    create_runcommand_script

    cp "$ROOT_DIR/resources/es/es_input.cfg" "$ES_CONFIG_DIR"
    # # 임시 디렉토리 정리 (선택 사항 - 빌드가 완료된 후)
    # log_msg INFO "임시 빌드 디렉토리($TEMP_DIR) 정리 중..."
    # rm -rf "$TEMP_DIR" || log_msg WARN "임시 디렉토리 정리 실패."
    
    log_msg INFO "사용자($__user:$__user)권한 처리($USER_SHARE_PATH)중..."
    chown -R $__user:$__user "$USER_SHARE_PATH" || return 1
    log_msg INFO "사용자 권한 처리 완료."
    log_msg SUCCESS "환경 설정 및 패치 완료."
    return 0
}

setup_environment