#!/usr/bin/env bash

# =======================================================
# Retro Pangui UI Library
# 파일명: ui.sh
# 설명: Retro Pangui의 모든 dialog 메뉴 및 UI 관련 함수를 정의합니다.
#       이 파일은 실행 파일이 아니며, 메인 스크립트가 source하여 사용합니다.
# =======================================================

# ----------------- 초기화 함수 (Initialization Function) -----------------
# 핵심 의존성(dependency) 패키지 설치 및 모듈 다운로드를 확인하고 진행하는 함수
function install_core_dependencies() {
    # dialog, git 등 스크립트 실행에 필요한 기본 유틸리티 목록
    local CORE_DEPS=("dialog" "git" "wget" "curl" "unzip")
    local MISSING_DEPS=()

    log_msg INFO "필수 유틸리티 누락 여부 확인 중..."

    for dep in "${CORE_DEPS[@]}"; do
        if ! command_exists "$dep"; then
            MISSING_DEPS+=("$dep")
        fi
    done

    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        log_msg WARN "다음 필수 유틸리티가 누락되었습니다: ${MISSING_DEPS[*]}"
        log_msg INFO "설치 패키지 목록을 업데이트하고 설치를 진행합니다."

        sudo apt-get update
        sudo apt-get upgrade -y
        sudo apt-get install -y "${MISSING_DEPS[@]}"

        if [ $? -ne 0 ]; then
            log_msg ERROR "필수 유틸리티 설치에 실패했습니다. 네트워크 상태를 확인하십시오."
            exit 1
        fi
        log_msg INFO "필수 유틸리티 설치 완료."
    else
        log_msg INFO "모든 필수 유틸리티가 시스템에 존재합니다."
    fi

    # --- RetroPie 스크립트 모듈 다운로드 로직 ---
    log_msg INFO "RetroPie 스크립트 모듈 다운로드 확인..."

    local RETROPIE_SETUP_DIR="$MODULES_DIR/retropie_setup"
    local EXT_FOLDER="$(get_Git_Project_Dir_Name "$RETROPIE_SETUP_GIT_URL")"

    git_Pull_Or_Clone "$RETROPIE_SETUP_GIT_URL" "$TEMP_DIR_BASE/$EXT_FOLDER" --depth=1 --no-tags

    # retropie_setup 디렉토리가 없으면 생성
    mkdir -p "$RETROPIE_SETUP_DIR"

    # 원본 파일들을 복사하여 덮어쓰기
    rsync -avzr "$TEMP_DIR_BASE/$EXT_FOLDER/scriptmodules" "$RETROPIE_SETUP_DIR"
    rsync -avzr "$TEMP_DIR_BASE/$EXT_FOLDER/retropie_packages.sh" "$RETROPIE_SETUP_DIR"
    rsync -avzr "$TEMP_DIR_BASE/$EXT_FOLDER/retropie_setup.sh" "$RETROPIE_SETUP_DIR"
    log_msg SUCCESS "RetroPie 스크립트 모듈을 성공적으로 복사/업데이트했습니다."

    # 작업 완료 후 임시 디렉토리 삭제
    sudo rm -rf "$TEMP_DIR_BASE/$EXT_FOLDER"
}

# dialog 종료 상태를 처리하고 적절한 로그 메시지를 출력하는 헬퍼 함수
# 반환값: 0 (OK), 1 (Cancel/ESC/기타)
function handle_dialog_exitstatus() {
    local exitstatus=$1
    local menu_name="$2"

    if [ "$exitstatus" -eq 0 ]; then
        log_msg DEBUG "\"$menu_name\" 메뉴에서 [확인] 버튼이 눌렸습니다."
        return 0
    elif [ "$exitstatus" -eq 1 ]; then
        log_msg INFO "\"$menu_name\" 메뉴에서 [취소] 버튼이 눌렸습니다. 이전 메뉴로 돌아갑니다."
        return 1
    elif [ "$exitstatus" -eq 255 ]; then
        log_msg INFO "\"$menu_name\" 메뉴에서 [ESC] 키가 눌렸습니다. 이전 메뉴로 돌아갑니다."
        return 1
    else
        log_msg WARN "\"$menu_name\" 메뉴에서 알 수 없는 종료 상태($exitstatus)가 발생했습니다. 이전 메뉴로 돌아갑니다."
        return 1
    fi
}

# ----------------- 메인 메뉴 함수 (Main Menu Functions) -----------------

# [1] Base System 설치 (모듈 호출)
function run_base_system_install() {
    log_msg "DEBUG" "ui.sh: run_base_system_install 함수 진입."
    dialog --clear --title "Base System 설치" --yesno "RetroArch/EmulationStation 설치 및 Recalbox 환경 구축/패치를 진행하시겠습니까?\n\n(참고: 설치 진행 상황은 터미널에 직접 출력됩니다.)" 12 60 2>&1 >/dev/tty
    local dialog_exitstatus=$?
    if handle_dialog_exitstatus "$dialog_exitstatus" "Base System 설치 확인"; then
        log_msg INFO "Base System 설치 모듈(system_install.sh)을 실행합니다."
        
        log_msg INFO "========================================================"
        log_msg INFO "   🚀 Retro Pangui Base System 설치를 시작합니다..."
        log_msg INFO "========================================================"
        
        # system_install.sh 모듈을 source하여 실행
        source "$MODULES_DIR/system_install.sh"
        local INSTALL_STATUS=$?
        
        log_msg INFO "\n========================================================"
        
        if [ $INSTALL_STATUS -eq 0 ]; then
            dialog --clear --title "✅ 설치 성공" --msgbox "Base System 설치 및 환경 패치가 완료되었습니다." 10 60 2>&1 >/dev/tty
            log_msg INFO "Base System 설치가 성공적으로 완료되었습니다."
        else
            dialog --clear --title "❌ 설치 실패" --msgbox "설치 모듈 실행 중 오류가 발생했습니다. 상세한 실패 원인은 로그 파일을 확인하십시오: $LOG_FILE" 10 60 2>&1 >/dev/tty
            log_msg ERROR "Base System 설치 모듈 실행 중 오류 발생. 상세 로그 파일 확인 필요."
        fi
    fi
}

# [3] 패키지 관리 메뉴 (서브 메뉴)

# 카테고리별 패키지 관리 메뉴를 표시하는 함수
function manage_packages_by_section() {
    local section_title="$1"
    local section_id="$2"

    while true; do
        log_msg INFO "$section_title 관리 메뉴에 진입했습니다."

        local term_height=$(tput lines 2>/dev/null || echo 24)
        local term_width=$(tput cols 2>/dev/null || echo 80)
        local box_width=$((term_width - 4))
        [[ "$box_width" -gt 78 ]] && box_width=78
        [[ "$box_width" -lt 60 ]] && box_width=60
        local box_height=$((term_height - 4))
        [[ "$box_height" -lt 10 ]] && box_height=10
        local list_height=$((box_height - 8))
        [[ "$list_height" -lt 1 ]] && list_height=1
        local desc_width=$((box_width - 30))
        [[ "$desc_width" -lt 20 ]] && desc_width=20

        log_msg DEBUG "Terminal: ${term_height}x${term_width}, Box: ${box_height}x${box_width}, Desc: ${desc_width}"

        local options=()
        declare -A module_info

        while IFS= read -r -d '' id && IFS= read -r -d '' desc && IFS= read -r -d '' section && IFS= read -r -d '' type && IFS= read -r -d '' status; do
            if [[ "$section" == "$section_id" ]]; then
                local status_icon="[ ]"
                if [[ "$status" == "ON" ]]; then
                    status_icon="[✔]"
                fi
                options+=("$id" "$status_icon $desc")
                module_info["$id,type"]="$type"
                module_info["$id,status"]="$status"
            fi
        done < <(get_packages_with_update_status "$desc_width")

        if [ ${#options[@]} -eq 0 ]; then
            dialog --clear --title "정보" --msgbox "이 섹션에는 현재 플랫폼에서 설치 가능한 패키지가 없습니다." 8 70 2>&1 >/dev/tty
            return
        fi

        local CHOICE
        exec 3>&1
        CHOICE=$(dialog --clear --title "$section_title" --menu "패키지를 선택하세요 (설치됨: ✔)." "$box_height" "$box_width" "$list_height" "${options[@]}" 2>&1 1>&3)
        local exitstatus=$?
        exec 3>&-
        if handle_dialog_exitstatus "$exitstatus" "$section_title 관리"; then
            package_action_menu "$CHOICE" "${module_info["$CHOICE,type"]}" "${module_info["$CHOICE,status"]}"
        else
            break
        fi
    done
}

# 개별 패키지 액션 메뉴
function package_action_menu() {
    local module_id="$1"
    local module_type="$2"
    local is_installed="$3"
    local choice

    local status_text="미설치"
    if [[ "$is_installed" == "ON" ]]; then
        status_text="설치됨"
    fi

    while true; do
        exec 3>&1
        choice=$(dialog --clear --title "패키지: $module_id" --menu "상태: $status_text\n\n수행할 작업을 선택하세요." 18 78 10 \
            "install"  "패키지 설치/업데이트" \
            "remove"   "패키지 제거" \
            "info"     "패키지 정보 보기" \
            "back"     "뒤로" 2>&1 1>&3)
        local exitstatus=$?
        exec 3>&-
        log_msg DEBUG "Dialog exitstatus: $exitstatus"
        if handle_dialog_exitstatus "$exitstatus" "패키지: $module_id"; then
            case "$choice" in
                install)
                    if [[ "$is_installed" == "ON" ]]; then
                        if !(dialog --clear --title "경고" --yesno "이 패키지는 이미 설치되어 있습니다.\n다시 설치(업데이트) 하시겠습니까?" 10 60 2>&1 >/dev/tty); then
                            continue
                        fi
                    fi
                    clear
                    echo "===================================================="
                    echo "  INSTALLING: $module_id ($module_type)"
                    echo "===================================================="
                    install_module "$module_id" "$module_type"
                    echo "----------------------------------------------------"
                    read -p "작업이 완료되었습니다. 메뉴로 돌아가려면 [Enter]를 누르세요."
                    break
                    ;;
                remove)
                    if [[ "$is_installed" != "ON" ]]; then
                        dialog --clear --title "오류" --msgbox "이 패키지는 설치되어 있지 않습니다." 8 78 2>&1 >/dev/tty
                        continue
                    fi
                    if (dialog --clear --title "확인" --yesno "정말로 '$module_id' 패키지를 제거하시겠습니까?\n이 작업은 되돌릴 수 없습니다." 10 60 2>&1 >/dev/tty); then
                        clear
                        echo "===================================================="
                        echo "  REMOVING: $module_id ($module_type)"
                        echo "===================================================="
                        remove_module "$module_id" "$module_type"
                        echo "----------------------------------------------------"
                        read -p "제거 작업이 완료되었습니다. 메뉴로 돌아가려면 [Enter]를 누르세요."
                        break
                    fi
                    ;;
                info)
                    show_package_info "$module_id" "$module_type"
                    ;;
                back)
                    break
                    ;;
            esac
        else
            break
        fi
    done
}

function show_package_info() {
    local module_id="$1"
    local module_type="$2"

    log_msg INFO "정보 보기: $module_id"

    local script_path="$MODULES_DIR/retropie_setup/scriptmodules/$module_type/$module_id.sh"
    if [[ ! -f "$script_path" ]]; then
        dialog --clear --title "오류" --msgbox "스크립트 파일을 찾을 수 없습니다:\n$script_path" 8 78 2>&1 >/dev/tty
        return
    fi

    # romdir, biosdir 변수를 설정하고 서브셸에서 스크립트를 source하여 변수가 확장된 help_text를 가져옴
    local help_text=$(romdir="$USER_ROMS_PATH"; biosdir="$USER_BIOS_PATH"; source "$script_path"; echo "$rp_module_help")

    if [[ -z "$help_text" ]]; then
        help_text="이 패키지에 대한 정보가 없습니다."
    fi

            dialog --clear --title "정보: $module_id" --msgbox "$help_text" 20 78 2>&1 >/dev/tty
}

# 새로운 패키지 관리 메인 메뉴
function package_management_menu() {
    local choice
    while true; do
        choice=$(dialog --clear --title "패키지 관리" --menu "관리할 패키지 섹션을 선택하세요." 18 78 10 \
            "base"     "base 패키지" \
            "main"     "메인 패키지" \
            "opt"      "선택적 패키지" \
            "exp"      "실험적 패키지" \
            "driver"   "드라이버" \
            "config"   "설정 작업" \
            "depends"  "의존성" \
            "back"     "뒤로" 2>&1 >/dev/tty)

        local exitstatus=$?
        if [ $exitstatus -ne 0 ]; then
            break
        fi

        case "$choice" in
            base|main|opt|exp|driver)
                manage_packages_by_section "$choice 패키지" "$choice"
                ;;
            config|depends)
                dialog --clear --title "알림" --msgbox "이 섹션의 관리는 아직 지원되지 않습니다." 8 78 2>&1 >/dev/tty
                ;;
            back)
                break
                ;;
        esac
    done
}

# [4] 설정 / 기타 도구 메뉴 (서브 메뉴)
function config_tools_menu() {
    log_msg INFO "설정 / 기타 도구 메뉴에 진입했습니다."
    while true; do
        exec 3>&1
        CHOICE=$(dialog --clear --title "설정 / 기타 도구" --menu "실행할 도구를 선택하세요." 18 80 10 \
            "install_es_startup" "시스템 시작 시 ES 실행" \
            "configure_samba" "삼바(Samba) 설정 및 활성화" \
            "set_share_path_option" "Share 폴더 경로 설정 (현재: $USER_SHARE_PATH)" \
            "back" "뒤로"  2>&1 1>&3)
        local exitstatus=$?
        exec 3>&-
                if handle_dialog_exitstatus "$exitstatus" "설정 / 기타 도구"; then
                    case $CHOICE in
                        install_es_startup) log_msg INFO "설정/도구 항목 install_es_startup 선택. 로직 미구현."
                            dialog --clear --title "알림" --msgbox "세부 설정 로직은 추가 구현이 필요합니다." 8 60 2>&1 >/dev/tty ;;
                        configure_samba) configure_samba_share ;;
                        set_share_path_option) set_share_path ;;
                        back) break ;;
                    esac
                else
                    break
                fi    done
}

# Share 폴더 경로 설정 함수 (경로 변경 로직)
function set_share_path() {
    log_msg INFO "Share 폴더 경로 설정 시작 (현재: $USER_SHARE_PATH)"

    local NEW_PATH
    exec 3>&1
    NEW_PATH=$(dialog --clear --title "Retro Pangui Share 경로 설정" --inputbox \
        "Retro Pangui 'share' 폴더의 절대 경로를 입력하세요.\n(현재 경로: $USER_SHARE_PATH)" 10 80 "$USER_SHARE_PATH" 2>&1 1>&3)
    local dialog_exitstatus=$?
    exec 3>&-

    if ! handle_dialog_exitstatus "$dialog_exitstatus" "Share 경로 설정"; then
        log_msg INFO "Share 폴더 경로 설정이 사용자에 의해 취소되었습니다."
        return 1 # User cancelled
    fi

    # Check if the new path exists
    if [ ! -d "$NEW_PATH" ]; then
        # If not, ask the user if they want to create it
        dialog --clear --title "경로 없음" --yesno "입력하신 경로 '$NEW_PATH'가 존재하지 않습니다. 새로 생성하시겠습니까?" 8 80 2>&1 >/dev/tty
        local create_dir_exitstatus=$?
        if ! handle_dialog_exitstatus "$create_dir_exitstatus" "경로 생성 확인"; then
            log_msg INFO "Share 폴더 경로 생성이 취소되었습니다."
            return 1 # User chose not to create
        fi

        # Create the directory and set ownership using set_dir_ownership_and_permissions
        log_msg INFO "새 Share 폴더 '$NEW_PATH' 생성 및 권한 설정 중."
        local effective_user=$(set_dir_ownership_and_permissions "$NEW_PATH")
        if [ $? -ne 0 ]; then
            log_msg ERROR "Share 폴더 '$NEW_PATH' 생성 및 권한 설정에 실패했습니다."
            dialog --clear --title "오류" --msgbox "Share 폴더 '$NEW_PATH' 생성 및 권한 설정에 실패했습니다." 10 60 2>&1 >/dev/tty
            return 1
        fi
        log_msg SUCCESS "Share 폴더 '$NEW_PATH' 생성 및 권한 설정 완료. 소유자: $effective_user"
    fi

    # Update the USER_SHARE_PATH variable in config.sh
    local CONFIG_FILE="$MODULES_DIR/config.sh"
    config_set "USER_SHARE_PATH" "$NEW_PATH" "$CONFIG_FILE"

    # Update the in-memory variable for the current script execution
    USER_SHARE_PATH="$NEW_PATH"

    dialog --clear --title "경로 설정 완료" --msgbox "Retro Pangui Share 경로가 '$USER_SHARE_PATH' 로 설정되었습니다." 8 80 2>&1 >/dev/tty
    log_msg INFO "Share 경로가 '$USER_SHARE_PATH' 로 성공적으로 변경되었습니다."
    return 0
}

function configure_samba_share() {
    log_msg INFO "Samba 설정 및 활성화 시작."

    # 1. Samba 패키지 설치 확인 및 설치
    local SAMBA_DEPS=("samba" "samba-common-bin")
    local MISSING_SAMBA_DEPS=()

    for dep in "${SAMBA_DEPS[@]}"; do
        if ! command_exists "$dep"; then
            MISSING_SAMBA_DEPS+=("$dep")
        fi
    done

    if [ ${#MISSING_SAMBA_DEPS[@]} -gt 0 ]; then
        log_msg INFO "누락된 Samba 패키지 설치 중: ${MISSING_SAMBA_DEPS[*]}"
        sudo apt-get update && sudo apt-get install -y "${MISSING_SAMBA_DEPS[@]}"
        if [ $? -ne 0 ]; then
            log_msg ERROR "Samba 패키지 설치에 실패했습니다."
            dialog --clear --title "오류" --msgbox "Samba 패키지 설치에 실패했습니다. 네트워크 상태를 확인하거나 수동으로 설치해주세요." 10 60 2>&1 >/dev/tty
            return 1
        fi
        log_msg SUCCESS "Samba 패키지 설치 완료."
    else
        log_msg INFO "모든 Samba 패키지가 이미 설치되어 있습니다."
    fi

    # 2. smb.conf 설정
    local SMB_CONF="/etc/samba/smb.conf"
    local SHARE_NAME="RetroPanguiShare" # 공유 이름
    local SHARE_PATH="$USER_SHARE_PATH" # config.sh에서 정의된 경로

    log_msg INFO "Samba 공유 설정 업데이트 중: $SMB_CONF"

    # 기존 공유 설정 제거 (중복 방지)
    sudo sed -i "/^\[$SHARE_NAME\]/,/^\s*\[/d" "$SMB_CONF"
    sudo sed -i "/^\[$SHARE_NAME\]/d" "$SMB_CONF" # 혹시 마지막에 있으면 제거

    # 새 공유 설정 추가
    sudo bash -c "cat >> \"$SMB_CONF\" << EOF
[$SHARE_NAME]
   path = $SHARE_PATH
   comment = Retro Pangui Share
   browseable = yes
   writeable = yes
   create mask = 0664
   directory mask = 0775
   public = yes
   guest ok = yes
EOF"

    if [ $? -ne 0 ]; then
        log_msg ERROR "smb.conf 파일 업데이트에 실패했습니다."
        dialog --clear --title "오류" --msgbox "smb.conf 파일 업데이트에 실패했습니다. 권한을 확인해주세요." 10 60 2>&1 >/dev/tty
        return 1
    fi
    log_msg SUCCESS "smb.conf 파일 업데이트 완료."

    # 3. 공유 폴더 권한 설정
    log_msg INFO "공유 폴더($SHARE_PATH) 권한 설정 중."
    # func.sh의 set_dir_ownership_and_permissions 함수를 사용하여 소유권 및 권한 설정
    local effective_user=$(set_dir_ownership_and_permissions "$SHARE_PATH")
    if [ $? -ne 0 ]; then
        log_msg ERROR "공유 폴더 권한 설정에 실패했습니다."
        dialog --clear --title "오류" --msgbox "공유 폴더($SHARE_PATH) 권한 설정에 실패했습니다." 10 60 2>&1 >/dev/tty
        return 1
    fi
    log_msg SUCCESS "공유 폴더($SHARE_PATH) 권한 설정 완료. 소유자: $effective_user"

    # 4. Samba 서비스 재시작 및 활성화
    log_msg INFO "Samba 서비스 재시작 및 활성화 중."
    sudo systemctl daemon-reload
    sudo systemctl restart smbd nmbd
    sudo systemctl enable smbd nmbd
    if [ $? -ne 0 ]; then
        log_msg ERROR "Samba 서비스 재시작/활성화에 실패했습니다."
        dialog --clear --title "오류" --msgbox "Samba 서비스 재시작/활성화에 실패했습니다." 10 60 2>&1 >/dev/tty
        return 1
    fi
    log_msg SUCCESS "Samba 서비스 활성화 및 재시작 완료."

    dialog --clear --title "Samba 설정 완료" --msgbox "Samba 공유가 성공적으로 설정 및 활성화되었습니다.\n공유 경로: $SHARE_PATH" 10 60 2>&1 >/dev/tty
    log_msg INFO "Samba 설정 및 활성화 완료."
    return 0
}

# [5] 스크립트 업데이트 (Git 기반)
function update_script() {
    log_msg INFO "스크립트 업데이트 확인 중..."
    dialog --clear --title "업데이트 확인" --infobox "원격 저장소에서 최신 버전 정보를 가져오는 중..." 8 60 2>&1 >/dev/tty

    # 원격 저장소의 태그 목록을 가져옵니다.
    local remote_tags=$(git ls-remote --tags origin | awk '{print $2}' | grep -o 'v[0-9]\+\.[0-9]\+\(\.[0-9]\+\)*$' | sort -V | tail -n 1)

    if [ -z "$remote_tags" ]; then
        log_msg WARN "원격 버전(태그) 정보를 찾을 수 없습니다. 업데이트를 진행할 수 없습니다."
        dialog --clear --title "알림" --msgbox "확인 가능한 원격 버전 정보(태그)가 없습니다. 업데이트를 진행할 수 없습니다." 8 78 2>&1 >/dev/tty
        return
    fi

    local __rpg_latest_remote_version=$remote_tags
    local remote_version_num=${__rpg_latest_remote_version//v/}
    local local_version_num=${__version//v/}

    log_msg INFO "버전 비교: Local='v${local_version_num}', Remote='${__rpg_latest_remote_version}'"

    # 버전 비교 (sort -V 사용)
    if [ "$(printf '%s\n' "$remote_version_num" "$local_version_num" | sort -V | tail -n 1)" != "$local_version_num" ]; then
        
        # 최종 디버깅 출력
        log_msg DEBUG "local_version_num=${local_version_num}"
        log_msg DEBUG "__rpg_latest_remote_version=${__rpg_latest_remote_version}"

                    if (dialog --clear --title "스크립트 업데이트" --yesno "새로운 버전의 스크립트를 사용할 수 있습니다.\n\n현재 버전: v${local_version_num}\n최신 버전: ${__rpg_latest_remote_version}\n\n업데이트를 진행하시겠습니까?" 12 60 2>&1 >/dev/tty); then            log_msg INFO "retropangui 스크립트 업데이트 시작."
            
            local stashed=false
            if [ -n "$(git status --porcelain)" ]; then
                log_msg INFO "로컬 변경사항을 임시 저장합니다."
                if ! git stash push -u -m "RetroPangui-Auto-Stash-Before-Update"; then
                    log_msg ERROR "로컬 변경사항 임시 저장 실패."
                    dialog --clear --title "업데이트 실패" --msgbox "로컬 변경사항을 임시 저장하는 데 실패했습니다. 업데이트를 진행할 수 없습니다." 10 78 2>&1 >/dev/tty
                    return
                fi
                stashed=true
            fi

            log_msg INFO "원격 저장소에서 업데이트를 가져옵니다."
            if ! git pull --rebase origin main > >(tee -a "$LOG_FILE") 2>&1; then
                log_msg ERROR "업데이트 실패 ('git pull --rebase' 실패)."
                dialog --clear --title "업데이트 실패" --msgbox "업데이트를 가져오는 데 실패했습니다. 자세한 내용은 로그를 확인하세요." 8 78 2>&1 >/dev/tty
                if $stashed; then
                    git stash pop
                fi
                return
            fi

            if $stashed; then
                log_msg INFO "임시 저장된 로컬 변경사항을 다시 적용합니다."
                if ! git stash pop; then
                    log_msg WARN "로컬 변경사항 적용 중 충돌이 발생했습니다. 로컬 변경사항을 롤백합니다."
                    git reset --hard
                    dialog --clear --title "업데이트 완료 (주의)" --msgbox "스크립트가 성공적으로 업데이트되었습니다.\n\n하지만, 로컬 수정사항 중 일부를 자동으로 재적용할 수 없었습니다. 변경하신 내용은 안전하게 백업되어 있으니, 전문가의 도움이 필요할 수 있습니다. (가장 최근 stash 확인)" 12 78 2>&1 >/dev/tty
                else
                    log_msg SUCCESS "로컬 변경사항을 성공적으로 다시 적용했습니다."
                    dialog --clear --title "업데이트 완료" --msgbox "스크립트가 성공적으로 업데이트되었으며, 로컬 변경사항도 유지되었습니다." 10 78 2>&1 >/dev/tty
                    dialog --clear --title "안내" --msgbox "RetroArch 등 개별 구성요소의 업데이트는 '패키지 관리' 메뉴에서 확인하세요." 10 78 2>&1 >/dev/tty
                fi
            else
                dialog --clear --title "업데이트 완료" --msgbox "스크립트가 성공적으로 업데이트되었습니다." 8 78 2>&1 >/dev/tty
                dialog --clear --title "안내" --msgbox "RetroArch 등 개별 구성요소의 업데이트는 '패키지 관리' 메뉴에서 확인하세요." 10 78 2>&1 >/dev/tty
            fi

        else
            log_msg INFO "스크립트 업데이트가 사용자에 의해 취소되었습니다."
        fi
    else
        log_msg INFO "스크립트가 이미 최신 버전입니다."
        dialog --clear --title "스크립트 업데이트" --msgbox "현재 최신 버전의 스크립트를 사용하고 있습니다.\n\n현재 버전: v${local_version_num}" 10 60 2>&1 >/dev/tty
    fi
}

# [6] 전부 설치 제거 (Share 폴더 제외)
function uninstall_all() {
    if (dialog --clear --title "전체 설치 제거" --yesno "Retro Pangui가 생성한 모든 설정, 로그, 빌드 파일, 설치된 코어 및 에뮬레이터를 제거합니다. (Share 폴더 제외)\n\n이 작업은 되돌릴 수 없습니다. 정말로 계속하시겠습니까?" 12 70 2>&1 >/dev/tty);
 then
        log_msg INFO "전체 설치 제거 시작."
        (
            log_and_gauge "10" "로그 및 임시 파일 제거 중..."
            sudo rm -rf "$LOG_DIR" "$TEMP_DIR_BASE" > /dev/null 2>&1
            log_and_gauge "30" "EmulationStation 설정 제거 중..."
            sudo rm -rf "$ES_CONFIG_DIR" > /dev/null 2>&1
            log_and_gauge "50" "RetroArch 설정 제거 중..."
            sudo rm -rf "$RA_CONFIG_DIR" > /dev/null 2>&1
            log_and_gauge "70" "설치된 코어 및 에뮬레이터 제거 중..."
            sudo rm -rf "$INSTALL_ROOT_DIR" "$LIBRETRO_CORE_PATH" > /dev/null 2>&1
            log_and_gauge "90" "빌드 파일 제거 중..."
            sudo rm -rf "$INSTALL_BUILD_DIR" > /dev/null 2>&1
            log_and_gauge "100" "정리 완료."
        ) | dialog --clear --title "전체 제거 진행" --gauge "생성된 파일 정리 중..." 8 60 0 2>&1 >/dev/tty
        
        dialog --clear --title "완료" --msgbox "모든 생성 파일(Share 폴더 제외) 제거가 완료되었습니다." 8 60 2>&1 >/dev/tty
        log_msg INFO "전체 설치 제거 완료."
    else
        log_msg INFO "전체 설치 제거가 사용자에 의해 취소되었습니다."
    fi
}

# [7] 시스템 재부팅
function reboot_system() {
    if (dialog --clear --title "시스템 재부팅" --yesno "시스템을 지금 바로 재부팅하시겠습니까?" 10 60 2>&1 >/dev/tty);
 then
        log_msg WARN "시스템 재부팅을 시작합니다."
        dialog --clear --title "재부팅" --msgbox "시스템을 3초 후 재부팅합니다." 8 60 2>&1 >/dev/tty
        sleep 3
        sudo reboot
    fi
}

# ----------------- 메인 실행 로직 -----------------
function main_ui() {
    log_msg "DEBUG" "ui.sh: Entered main_ui function."
    # 함수 호출 시점에 필요한 변수들을 로컬로 선언
    local TITLE="Retro Pangui Configuration Manager (v$__version)"
    local MENU_TITLE="$TITLE [Share: $(basename $USER_SHARE_PATH)]"
    local MENU_PROMPT="메뉴를 선택하세요.\n(Share 경로 전체: $USER_SHARE_PATH)"

    # 최초 실행 시, 핵심 의존성 설치
    install_core_dependencies 
    
    while true; do
        # 메인 dialog 메뉴
        exec 3>&1
        CHOICE=$(dialog --clear --title "$MENU_TITLE" --menu "$MENU_PROMPT" $HEIGHT $WIDTH $CHOICE_HEIGHT \
            "install_base" "Base System 설치" \
            "manage_packages" "패키지 관리 (Base/Main/Driver)" \
            "config_tools" "설정 / 기타 도구" \
            "update_script" "스크립트 업데이트" \
            "uninstall_all" "전부 설치 제거 (Share 폴더 제외)" \
            "reboot_system" "시스템 재부팅" \
            "exit" "종료" 2>&1 1>&3)
        local exitstatus=$?
        exec 3>&-
        log_msg DEBUG "Dialog exitstatus: $exitstatus"
        if handle_dialog_exitstatus "$exitstatus" "Retro Pangui Configuration Manager"; then
            case $CHOICE in
                install_base) run_base_system_install ;;
                manage_packages) package_management_menu ;;
                config_tools) config_tools_menu ;;
                update_script) update_script ;;
                uninstall_all) uninstall_all ;;
                reboot_system) reboot_system ;;
                exit) break ;;
            esac
        else
            break
        fi
    done
    
    log_msg INFO "Retro Pangui Configuration Manager 종료."
    clear
}