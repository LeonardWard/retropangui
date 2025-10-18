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

    # # 설치 명령을 실행한 사용자의 UID를 가져와 소유권 설정에 사용합니다.
    local __user=$(stat -c '%U' "$TEMP_DIR")
    
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
    
    # Samba 서버 설치 및 설정
    log_msg STEP "Samba 서버 설치 및 설정 시작..."
    if ! dpkg -l | grep -q "samba"; then
        log_msg INFO "Samba 패키지 설치 중..."
        sudo apt-get update && sudo apt-get install -y samba
    else
        log_msg INFO "Samba가 이미 설치되어 있습니다."
    fi

    log_msg INFO "기존 Samba 설정 파일 백업 중 (/etc/samba/smb.conf.rp.bak)..."
    sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.rp.bak

    log_msg INFO "새로운 Samba 설정 파일 생성 중... (인증 필요)"
    local smb_conf="/etc/samba/smb.conf"
    local roms_path="$USER_SHARE_PATH/roms"
    local bios_path="$USER_SHARE_PATH/bios"
    local saves_path="$USER_SHARE_PATH/saves"

    # 공유 디렉토리 생성
    sudo mkdir -p "$roms_path" "$bios_path" "$saves_path"
    sudo chown -R $__user:$__user "$USER_SHARE_PATH"
    sudo chmod -R 0775 "$USER_SHARE_PATH"

    sudo bash -c "cat > $smb_conf" << EOF
[global]
   workgroup = WORKGROUP
   server string = RetroPangui
   netbios name = retropangui
   security = user
   dns proxy = no
   wins support = yes

[share]
   path = $USER_SHARE_PATH
   comment = RetroPangui Share
   browsable = yes
   writable = yes
   read only = no
   create mask = 0775
   directory mask = 0775
   force user = $__user

[roms]
   path = $roms_path
   comment = RetroPangui ROMs
   browsable = yes
   writable = yes
   read only = no
   create mask = 0775
   directory mask = 0775
   force user = $__user

[bios]
   path = $bios_path
   comment = RetroPangui BIOS
   browsable = yes
   writable = yes
   read only = no
   create mask = 0775
   directory mask = 0775
   force user = $__user

[saves]
   path = $saves_path
   comment = RetroPangui Saves
   browsable = yes
   writable = yes
   read only = no
   create mask = 0775
   directory mask = 0775
   force user = $__user
EOF

    log_msg INFO "Samba 서비스 재시작 중..."
    sudo systemctl restart smbd
    sudo systemctl restart nmbd
    log_msg SUCCESS "Samba 서버 설정 완료."
    log_msg WARN "Samba 공유 폴더에 접근하려면 사용자 계정을 생성해야 합니다."
    log_msg WARN "터미널에서 'sudo smbpasswd -a <사용자이름>' 명령을 실행하여 Samba 사용자 계정을 생성하고 비밀번호를 설정하세요."
    log_msg WARN "Windows에서 공유 폴더에 접근할 때 이 사용자 이름과 비밀번호를 사용해야 합니다."

    log_msg INFO "사용자($__user:$__user)권한 처리($USER_SHARE_PATH)중..."
    chown -R $__user:$__user "$USER_SHARE_PATH" || return 1
    log_msg INFO "사용자 권한 처리 완료."
    log_msg SUCCESS "환경 설정 및 패치 완료."

    # # 임시 디렉토리($TEMP_DIR) 정리
    # log_msg INFO "임시 빌드 디렉토리($TEMP_DIR) 정리 중..."
    # rm -rf "$TEMP_DIR" || log_msg WARN "임시 디렉토리($TEMP_DIR) 정리 실패."

    return 0
}

setup_environment