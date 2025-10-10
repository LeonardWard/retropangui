#!/usr/bin/env bash
#
# 파일명: install_base_5_in_5_setup_env.sh
# Retro Pangui Module: Environment Setup (Base 5/5)
# 
# 이 스크립트는 최종 환경 설정, Recalbox 설정 적용, 권한 설정을 처리하는 
# setup_environment 함수를 정의합니다.
# ===============================================

setup_environment() {
    log_msg STEP "Retro Pangui 환경 설정 및 Recalbox 설정 적용 시작..."

    # 기존 설정 백업 (RA, ES)
    backup_if_exists() {
        local src="$1"
        if [ -f "$src" ]; then
            cp "$src" "${src}.bak.$(date +%Y%m%d_%H%M%S)"
        fi
    }

    # 복사 직전 기존 파일 백업
    backup_if_exists "$RA_CONFIG_DIR/retroarch.cfg"
    backup_if_exists "$ES_CONFIG_DIR/es_systems.cfg"

    # 실패 시 안내 (에러 로그 경로 안내)
    if [ $? -ne 0 ]; then
        echo "에러 발생: 자세한 내용은 $LOG_DIR 또는 $USER_LOGS_PATH 를 확인하세요."
        exit 1
    fi

    # TEMP_DIR, USER_SHARE_PATH, INSTALL_DIR, RA_CONFIG_DIR, ES_CONFIG_DIR, RECALBOX_GIT_URL 
    # 등은 config.sh에서 정의됨
    local CONFIG_CLONE_DIR="$TEMP_DIR/recalbox-config"
    
    # 설치 명령을 실행한 사용자의 UID를 가져와 소유권 설정에 사용합니다.
    local __user=$(stat -c '%U' "$TEMP_DIR")
    
    # [1] 핵심 디렉토리 생성 및 권한 설정
    log_msg INFO "핵심 설치 디렉토리($INSTALL_ROOT_DIR, $LOG_DIR) 생성 및 권한 설정 중..."
    sudo mkdir -p "$INSTALL_ROOT_DIR" "$LOG_DIR" || return 1
    
    log_msg INFO "사용자 공유 경로($USER_SHARE_PATH) 생성 및 권한 설정 중..."
    # 이 공유 경로는 ES의 롬 경로로 사용됩니다.
    sudo mkdir -p "$USER_SHARE_PATH" || return 1
    
    # 설치된 바이너리 및 사용자 공유 폴더의 소유자를 원래의 사용자로 변경
    log_msg INFO "설치 경로 소유자를 사용자($__user)로 변경..."
    # Share 폴더의 모든 콘텐츠는 사용자 소유여야 합니다.
    sudo chown -R $__user:$__user "$USER_SHARE_PATH" || return 1
    
    # # [2] Recalbox 설정 파일 클론
    # log_msg INFO "Recalbox 설정 Git 저장소($RECALBOX_GIT_URL) 클론 중..."

    #     # 프로젝트 이름 추출 및 디렉터리 결정
    # RECALBOX_NAME="$(get_git_project_dir_name "$RECALBOX_GIT_URL")"
    # echo "ℹ️ Recalbox 프로젝트 이름: $RECALBOX_NAME"
    # RECALBOX_GIT_DIR="$INSTALL_BUILD_DIR/$RECALBOX_NAME"
    # echo "ℹ️ Recalbox 디렉토리: $RECALBOX_GIT_DIR"
    # git clone "$RECALBOX_GIT_URL" "$RECALBOX_GIT_DIR" || { log_msg ERROR "Recalbox 설정 클론 실패."; return 1; }
    
    # # [3] RetroArch 설정
    # log_msg INFO "RetroArch 설정 파일 복사 및 패치 중..."
    # mkdir -p "$RA_CONFIG_DIR" || return 1
    # chown -R $__user:$__user "$RA_CONFIG_DIR" || return 1

    # local RECALBOX_RA_CFG="$RECALBOX_GIT_DIR/config/retroarch/retroarch.cfg"

    # if [ -f "$RECALBOX_RA_CFG" ]; then
    #     cp "$RECALBOX_RA_CFG" "$RA_CONFIG_DIR/retroarch.cfg" || { log_msg ERROR "RetroArch 설정 파일 복사 실패."; return 1; }
    #     log_msg INFO "기본 retroarch.cfg 복사 완료."
    # else
    #     log_msg WARN "Recalbox retroarch.cfg 템플릿을 찾을 수 없습니다. (경로: $RECALBOX_RA_CFG)"
    # fi
    
    # # [4] EmulationStation 설정 (업데이트됨)
    # log_msg INFO "EmulationStation 설정 디렉토리 생성 및 Recalbox 설정 적용 중..."
    # mkdir -p "$ES_CONFIG_DIR" || return 1
    # chown -R $__user:$__user "$ES_CONFIG_DIR" || return 1
    
    # local RECALBOX_ES_CFG="$CONFIG_CLONE_DIR/config/emulationstation/es_systems.cfg"
    # local ES_THEMES_SRC="$CONFIG_CLONE_DIR/themes"
    
    # # a) es_systems.cfg 복사
    # if [ -f "$RECALBOX_ES_CFG" ]; then
    #     cp "$RECALBOX_ES_CFG" "$ES_CONFIG_DIR/es_systems.cfg" || { log_msg ERROR "ES systems 설정 파일 복사 실패."; return 1; }
    #     log_msg INFO "기본 es_systems.cfg 복사 완료."
    # else
    #     log_msg WARN "Recalbox es_systems.cfg 템플릿을 찾을 수 없습니다. (경로: $RECALBOX_ES_CFG)"
    # fi
    
    # # b) Recalbox의 테마 복사 (선택 사항, 기본 테마가 없는 경우를 대비)
    # if [ -d "$ES_THEMES_SRC" ]; then
    #     log_msg INFO "Recalbox 테마 파일 복사 중..."
    #     cp -R "$ES_THEMES_SRC" "$ES_CONFIG_DIR/" || { log_msg ERROR "ES 테마 파일 복사 실패."; return 1; }
    #     log_msg INFO "Recalbox 테마 복사 완료."
    # else
    #     log_msg WARN "Recalbox 테마 템플릿을 찾을 수 없습니다. (경로: $ES_THEMES_SRC)"
    # fi

    # # [5] 임시 디렉토리 정리 (선택 사항 - 빌드가 완료된 후)
    # log_msg INFO "임시 빌드 디렉토리($TEMP_DIR) 정리 중..."
    # rm -rf "$TEMP_DIR" || log_msg WARN "임시 디렉토리 정리 실패."
    
    log_msg SUCCESS "환경 설정 및 패치 완료."
    return 0
}

setup_environment