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

    log_msg INFO "$(msg 'check_core_utils')"

    for dep in "${CORE_DEPS[@]}"; do
        if ! command_exists "$dep"; then
            MISSING_DEPS+=("$dep")
        fi
    done

    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        log_msg WARN "$(msg 'missing_utils'): ${MISSING_DEPS[*]}"
        log_msg INFO "$(msg 'update_and_install')"

        sudo apt-get update
        sudo apt-get upgrade -y
        sudo apt-get install -y "${MISSING_DEPS[@]}"

        if [ $? -ne 0 ]; then
            log_msg ERROR "$(msg 'core_util_install_failed')"
            exit 1
        fi
        log_msg INFO "$(msg 'core_util_install_complete')"
    else
        log_msg INFO "$(msg 'all_core_utils_exist')"
    fi

    # --- RetroPie 스크립트 모듈 다운로드 로직 ---
    log_msg INFO "$(msg 'check_retropie_modules')"

    local RETROPIE_SETUP_DIR="$MODULES_DIR/retropie_setup"
    local EXT_FOLDER="$(get_Git_Project_Dir_Name "$RETROPIE_SETUP_GIT_URL")"

    git_Pull_Or_Clone "$RETROPIE_SETUP_GIT_URL" "$TEMP_DIR_BASE/$EXT_FOLDER" --depth=1 --no-tags

    # retropie_setup 디렉토리가 없으면 생성
    mkdir -p "$RETROPIE_SETUP_DIR"

    # 원본 파일들을 복사하여 덮어쓰기
    rsync -avzr "$TEMP_DIR_BASE/$EXT_FOLDER/scriptmodules" "$RETROPIE_SETUP_DIR"
    rsync -avzr "$TEMP_DIR_BASE/$EXT_FOLDER/retropie_packages.sh" "$RETROPIE_SETUP_DIR"
    rsync -avzr "$TEMP_DIR_BASE/$EXT_FOLDER/retropie_setup.sh" "$RETROPIE_SETUP_DIR"
    log_msg SUCCESS "$(msg 'retropie_modules_updated')"

    # 작업 완료 후 임시 디렉토리 삭제
    sudo rm -rf "$TEMP_DIR_BASE/$EXT_FOLDER"
}

# dialog 종료 상태를 처리하고 적절한 로그 메시지를 출력하는 헬퍼 함수
# 반환값: 0 (OK), 1 (Cancel/ESC/기타)
function handle_dialog_exitstatus() {
    local exitstatus=$1
    local menu_name="$2"

    if [ "$exitstatus" -eq 0 ]; then
        log_msg DEBUG "\"$menu_name\" $(msg 'dialog_ok_pressed')"
        return 0
    elif [ "$exitstatus" -eq 1 ]; then
        log_msg INFO "\"$menu_name\" $(msg 'dialog_cancel_pressed')"
        return 1
    elif [ "$exitstatus" -eq 255 ]; then
        log_msg INFO "\"$menu_name\" $(msg 'dialog_esc_pressed')"
        return 1
    else
        log_msg WARN "\"$menu_name\" $(msg 'dialog_unknown_exit') ($exitstatus)"
        return 1
    fi
}

# ----------------- 메인 메뉴 함수 (Main Menu Functions) -----------------

# [1] Base System 설치 (모듈 호출)
function run_base_system_install() {
    log_msg "DEBUG" "$(msg 'run_base_install_enter')"
    dialog --clear --title "$(msg 'title_base_install')" --yesno "$(msg 'msg_base_install_confirm')" 12 60 2>&1 >/dev/tty
    local dialog_exitstatus=$?
    if handle_dialog_exitstatus "$dialog_exitstatus" "$(msg 'title_base_install')"; then
        log_msg INFO "$(msg 'run_base_install_module')"

        log_msg INFO "========================================================"
        log_msg INFO "   $(msg 'base_install_start')"
        log_msg INFO "========================================================"

        source "$MODULES_DIR/pkg/system_install.sh"
        local INSTALL_STATUS=$?

        log_msg INFO "\n========================================================"

        if [ $INSTALL_STATUS -eq 0 ]; then
            dialog --clear --title "$(msg 'title_install_success')" --msgbox "$(msg 'msg_base_install_complete')" 10 60 2>&1 >/dev/tty
            log_msg INFO "$(msg 'base_install_success_log')"
        else
            dialog --clear --title "$(msg 'title_install_failed')" --msgbox "$(msg 'msg_base_install_error'): $LOG_FILE" 10 60 2>&1 >/dev/tty
            log_msg ERROR "$(msg 'base_install_error_log')"
        fi
    fi
}

# [3] 패키지 관리 메뉴 (서브 메뉴)

# 카테고리별 패키지 관리 메뉴를 표시하는 함수
function manage_packages_by_section() {
    local section_title="$1"
    local section_id="$2"

    while true; do
        log_msg INFO "$section_title $(msg 'section_menu_entered')"

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
            dialog --clear --title "$(msg 'title_info')" --msgbox "$(msg 'msg_no_packages_in_section')" 8 70 2>&1 >/dev/tty
            return
        fi

        local CHOICE
        exec 3>&1
        CHOICE=$(dialog --clear --title "$section_title" --menu "$(msg 'msg_select_package')" "$box_height" "$box_width" "$list_height" "${options[@]}" 2>&1 1>&3)
        local exitstatus=$?
        exec 3>&-
        if handle_dialog_exitstatus "$exitstatus" "$section_title"; then
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

    local status_text="$(msg 'msg_not_installed')"
    if [[ "$is_installed" == "ON" ]]; then
        status_text="$(msg 'msg_installed')"
    fi

    while true; do
        exec 3>&1
        choice=$(dialog --clear --title "$(msg 'title_package'): $module_id" --menu "$(msg 'msg_package_status'): $status_text\n\n$(msg 'msg_select_action')" 18 78 10 \
            "install"  "$(msg 'menu_install_update')" \
            "remove"   "$(msg 'menu_remove')" \
            "info"     "$(msg 'menu_info')" \
            "back"     "$(msg 'menu_back')" 2>&1 1>&3)
        local exitstatus=$?
        exec 3>&-
        log_msg DEBUG "Dialog exitstatus: $exitstatus"
        if handle_dialog_exitstatus "$exitstatus" "$(msg 'title_package'): $module_id"; then
            case "$choice" in
                install)
                    if [[ "$is_installed" == "ON" ]]; then
                        if !(dialog --clear --title "$(msg 'title_warning')" --yesno "$(msg 'msg_already_installed')" 10 60 2>&1 >/dev/tty); then
                            continue
                        fi
                    fi
                    clear
                    echo "===================================================="
                    echo "  INSTALLING: $module_id ($module_type)"
                    echo "===================================================="
                    install_module "$module_id" "$module_type"
                    echo "----------------------------------------------------"
                    read -p "$(msg 'prompt_task_complete')"
                    break
                    ;;
                remove)
                    if [[ "$is_installed" != "ON" ]]; then
                        dialog --clear --title "$(msg 'title_error')" --msgbox "$(msg 'msg_not_installed_error')" 8 78 2>&1 >/dev/tty
                        continue
                    fi
                    if (dialog --clear --title "$(msg 'title_confirm')" --yesno "$(msg 'msg_remove_confirm')" 10 60 2>&1 >/dev/tty); then
                        clear
                        echo "===================================================="
                        echo "  REMOVING: $module_id ($module_type)"
                        echo "===================================================="
                        remove_module "$module_id" "$module_type"
                        echo "----------------------------------------------------"
                        read -p "$(msg 'prompt_remove_complete')"
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

    log_msg INFO "$(msg 'show_package_info_log'): $module_id"

    local script_path="$MODULES_DIR/retropie_setup/scriptmodules/$module_type/$module_id.sh"
    if [[ ! -f "$script_path" ]]; then
        dialog --clear --title "$(msg 'title_error')" --msgbox "$(msg 'msg_script_not_found'):\n$script_path" 8 78 2>&1 >/dev/tty
        return
    fi

    # romdir, biosdir 변수를 설정하고 서브셸에서 스크립트를 source하여 변수가 확장된 help_text를 가져옴
    local help_text=$(romdir="$USER_ROMS_PATH"; biosdir="$USER_BIOS_PATH"; source "$script_path"; echo "$rp_module_help")

    if [[ -z "$help_text" ]]; then
        help_text="$(msg 'no_package_info')"
    fi

            dialog --clear --title "$(msg 'title_info'): $module_id" --msgbox "$help_text" 20 78 2>&1 >/dev/tty
}

# 새로운 패키지 관리 메인 메뉴
function package_management_menu() {
    local choice
    while true; do
        choice=$(dialog --clear --title "$(msg 'title_package_mgmt')" --menu "$(msg 'menu_select_section')" 18 78 10 \
            "base"     "$(msg 'menu_base_packages')" \
            "main"     "$(msg 'menu_main_packages')" \
            "opt"      "$(msg 'menu_opt_packages')" \
            "exp"      "$(msg 'menu_exp_packages')" \
            "driver"   "$(msg 'menu_drivers')" \
            "config"   "$(msg 'menu_config')" \
            "depends"  "$(msg 'menu_depends')" \
            "back"     "$(msg 'menu_back')" 2>&1 >/dev/tty)

        local exitstatus=$?
        if [ $exitstatus -ne 0 ]; then
            break
        fi

        case "$choice" in
            base|main|opt|exp|driver)
                manage_packages_by_section "$choice $(msg 'menu_base_packages')" "$choice"
                ;;
            config|depends)
                dialog --clear --title "$(msg 'title_notification')" --msgbox "$(msg 'msg_section_not_supported')" 8 78 2>&1 >/dev/tty
                ;;
            back)
                break
                ;;
        esac
    done
}

# [4] 설정 / 기타 도구 메뉴 (서브 메뉴)
function config_tools_menu() {
    log_msg INFO "$(msg 'config_tools_entered')"
    while true; do
        exec 3>&1
        CHOICE=$(dialog --clear --title "$(msg 'title_config_tools')" --menu "$(msg 'msg_select_tool')" 18 80 10 \
            "install_es_startup" "$(msg 'menu_es_startup')" \
            "configure_samba" "$(msg 'menu_samba_config')" \
            "set_share_path_option" "$(msg 'menu_share_path')" \
            "back" "$(msg 'menu_back')"  2>&1 1>&3)
        local exitstatus=$?
        exec 3>&-
                if handle_dialog_exitstatus "$exitstatus" "$(msg 'title_config_tools')"; then
                    case $CHOICE in
                        install_es_startup) log_msg INFO "$(msg 'config_tool_not_implemented')"
                            dialog --clear --title "$(msg 'title_notification')" --msgbox "$(msg 'msg_tool_not_implemented')" 8 60 2>&1 >/dev/tty ;;
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
    log_msg INFO "$(msg 'share_path_config_start') ($(msg 'using_generic_config'): $USER_SHARE_PATH)"

    local NEW_PATH
    exec 3>&1
    NEW_PATH=$(dialog --clear --title "$(msg 'title_share_path_config')" --inputbox \
        "$(msg 'msg_share_path_prompt')" 10 80 "$USER_SHARE_PATH" 2>&1 1>&3)
    local dialog_exitstatus=$?
    exec 3>&-

    if ! handle_dialog_exitstatus "$dialog_exitstatus" "$(msg 'title_share_path_config')"; then
        log_msg INFO "$(msg 'share_path_cancelled')"
        return 1 # User cancelled
    fi

    # Check if the new path exists
    if [ ! -d "$NEW_PATH" ]; then
        # If not, ask the user if they want to create it
        dialog --clear --title "$(msg 'title_path_not_exist')" --yesno "$(msg 'msg_path_not_exist'): '$NEW_PATH'" 8 80 2>&1 >/dev/tty
        local create_dir_exitstatus=$?
        if ! handle_dialog_exitstatus "$create_dir_exitstatus" "$(msg 'title_path_not_exist')"; then
            log_msg INFO "$(msg 'share_path_create_cancelled')"
            return 1 # User chose not to create
        fi

        # Create the directory and set ownership using set_dir_ownership_and_permissions
        log_msg INFO "$(msg 'share_path_creating'): '$NEW_PATH'"
        local effective_user=$(set_dir_ownership_and_permissions "$NEW_PATH")
        if [ $? -ne 0 ]; then
            log_msg ERROR "$(msg 'share_path_create_failed'): '$NEW_PATH'"
            dialog --clear --title "$(msg 'title_error')" --msgbox "$(msg 'msg_path_create_error'): '$NEW_PATH'" 10 60 2>&1 >/dev/tty
            return 1
        fi
        log_msg SUCCESS "$(msg 'share_path_create_success'): $effective_user"
    fi

    # Update the USER_SHARE_PATH variable in config.sh
    local CONFIG_FILE="$MODULES_DIR/config.sh"
    config_set "USER_SHARE_PATH" "$NEW_PATH" "$CONFIG_FILE"

    # Update the in-memory variable for the current script execution
    USER_SHARE_PATH="$NEW_PATH"

    dialog --clear --title "$(msg 'title_path_config_complete')" --msgbox "$(msg 'msg_path_set_complete') '$USER_SHARE_PATH'." 8 80 2>&1 >/dev/tty
    log_msg INFO "$(msg 'share_path_updated'): '$USER_SHARE_PATH'"
    return 0
}

function configure_samba_share() {
    log_msg INFO "$(msg 'samba_config_start')"

    # 1. Samba 패키지 설치 확인 및 설치
    local SAMBA_DEPS=("samba" "samba-common-bin")
    local MISSING_SAMBA_DEPS=()

    for dep in "${SAMBA_DEPS[@]}"; do
        if ! command_exists "$dep"; then
            MISSING_SAMBA_DEPS+=("$dep")
        fi
    done

    if [ ${#MISSING_SAMBA_DEPS[@]} -gt 0 ]; then
        log_msg INFO "$(msg 'missing_samba_installing'): ${MISSING_SAMBA_DEPS[*]}"
        sudo apt-get update && sudo apt-get install -y "${MISSING_SAMBA_DEPS[@]}"
        if [ $? -ne 0 ]; then
            log_msg ERROR "$(msg 'samba_install_failed')"
            dialog --clear --title "$(msg 'title_error')" --msgbox "$(msg 'msg_samba_install_error')" 10 60 2>&1 >/dev/tty
            return 1
        fi
        log_msg SUCCESS "$(msg 'samba_install_complete')"
    else
        log_msg INFO "$(msg 'samba_already_installed')"
    fi

    # 2. smb.conf 설정
    local SMB_CONF="/etc/samba/smb.conf"
    local SHARE_NAME="RetroPanguiShare" # 공유 이름
    local SHARE_PATH="$USER_SHARE_PATH" # config.sh에서 정의된 경로

    log_msg INFO "$(msg 'samba_config_updating'): $SMB_CONF"

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
        log_msg ERROR "$(msg 'samba_conf_update_failed')"
        dialog --clear --title "$(msg 'title_error')" --msgbox "$(msg 'msg_samba_conf_error')" 10 60 2>&1 >/dev/tty
        return 1
    fi
    log_msg SUCCESS "$(msg 'samba_conf_update_success')"

    # 3. 공유 폴더 권한 설정
    log_msg INFO "$(msg 'samba_share_perms_setting') ($SHARE_PATH)"
    # func.sh의 set_dir_ownership_and_permissions 함수를 사용하여 소유권 및 권한 설정
    local effective_user=$(set_dir_ownership_and_permissions "$SHARE_PATH")
    if [ $? -ne 0 ]; then
        log_msg ERROR "$(msg 'samba_share_perms_failed')"
        dialog --clear --title "$(msg 'title_error')" --msgbox "$(msg 'msg_samba_perms_error') ($SHARE_PATH)" 10 60 2>&1 >/dev/tty
        return 1
    fi
    log_msg SUCCESS "$(msg 'samba_share_perms_success'): $effective_user"

    # 4. Samba 서비스 재시작 및 활성화
    log_msg INFO "$(msg 'samba_service_restarting')"
    sudo systemctl daemon-reload
    sudo systemctl restart smbd nmbd
    sudo systemctl enable smbd nmbd
    if [ $? -ne 0 ]; then
        log_msg ERROR "$(msg 'samba_service_failed')"
        dialog --clear --title "$(msg 'title_error')" --msgbox "$(msg 'msg_samba_service_error')" 10 60 2>&1 >/dev/tty
        return 1
    fi
    log_msg SUCCESS "$(msg 'samba_service_success')"

    dialog --clear --title "$(msg 'title_samba_complete')" --msgbox "$(msg 'msg_samba_complete'): $SHARE_PATH" 10 60 2>&1 >/dev/tty
    log_msg INFO "$(msg 'samba_complete_log')"
    return 0
}

# [5] 스크립트 업데이트 (Git 기반)
function update_script() {
    log_msg INFO "$(msg 'script_update_checking')"
    dialog --clear --title "$(msg 'title_update_check')" --infobox "$(msg 'msg_fetching_update')" 8 60 2>&1 >/dev/tty

    # 원격 저장소의 태그 목록을 가져옵니다.
    local remote_tags=$(git ls-remote --tags origin | awk '{print $2}' | grep -o 'v[0-9]\+\.[0-9]\+\(\.[0-9]\+\)*$' | sort -V | tail -n 1)

    if [ -z "$remote_tags" ]; then
        log_msg WARN "$(msg 'no_remote_version')"
        dialog --clear --title "$(msg 'title_notification')" --msgbox "$(msg 'msg_no_remote_tags')" 8 78 2>&1 >/dev/tty
        return
    fi

    local __rpg_latest_remote_version=$remote_tags
    local remote_version_num=${__rpg_latest_remote_version//v/}
    local local_version_num=${__version//v/}

    log_msg INFO "$(msg 'version_compare_log'): Local='v${local_version_num}', Remote='${__rpg_latest_remote_version}'"

    # 버전 비교 (sort -V 사용)
    if [ "$(printf '%s\n' "$remote_version_num" "$local_version_num" | sort -V | tail -n 1)" != "$local_version_num" ]; then

        # 최종 디버깅 출력
        log_msg DEBUG "local_version_num=${local_version_num}"
        log_msg DEBUG "__rpg_latest_remote_version=${__rpg_latest_remote_version}"

                    if (dialog --clear --title "$(msg 'title_script_update')" --yesno "$(msg 'msg_new_version'): v${local_version_num}\n$(msg 'latest'): ${__rpg_latest_remote_version}\n\n" 12 60 2>&1 >/dev/tty); then            log_msg INFO "$(msg 'script_update_start')"

            # 원격 저장소 최신 정보 가져오기
            log_msg INFO "$(msg 'fetching_update')"
            if ! git fetch origin > >(tee -a "$LOG_FILE") 2>&1; then
                log_msg ERROR "$(msg 'update_failed')"
                dialog --clear --title "$(msg 'title_update_failed')" --msgbox "$(msg 'msg_pull_failed')" 8 78 2>&1 >/dev/tty
                return
            fi

            # 로컬 변경사항 무시하고 원격 버전으로 강제 업데이트
            log_msg INFO "Resetting to remote version (origin/master)..."
            if ! git reset --hard origin/master > >(tee -a "$LOG_FILE") 2>&1; then
                log_msg ERROR "$(msg 'update_failed')"
                dialog --clear --title "$(msg 'title_update_failed')" --msgbox "$(msg 'msg_pull_failed')" 8 78 2>&1 >/dev/tty
                return
            fi

            log_msg SUCCESS "$(msg 'stash_success')"
            dialog --clear --title "$(msg 'title_update_complete')" --msgbox "$(msg 'msg_update_restart')" 8 78 2>&1 >/dev/tty

            # 업데이트된 스크립트로 프로그램 재시작
            log_msg INFO "Restarting program with updated script..."
            clear
            exec sudo "$ROOT_DIR/retropangui_setup.sh" "$@"

        else
            log_msg INFO "$(msg 'script_update_cancelled')"
        fi
    else
        log_msg INFO "$(msg 'script_already_latest')"
        dialog --clear --title "$(msg 'title_script_update')" --msgbox "$(msg 'msg_already_latest'): v${local_version_num}" 10 60 2>&1 >/dev/tty
    fi
}

# [6] 전부 설치 제거 (Share 폴더 및 로그 제외)
function uninstall_all() {
    if (dialog --clear --title "$(msg 'title_uninstall_all')" --yesno "$(msg 'msg_uninstall_confirm')" 12 70 2>&1 >/dev/tty);
 then
        log_msg INFO "$(msg 'uninstall_all_start')"
        (
            log_and_gauge "10" "$(msg 'cleanup_temp')"
            sudo rm -rf "$TEMP_DIR_BASE" > /dev/null 2>&1
            log_and_gauge "30" "$(msg 'cleanup_es')"
            sudo rm -rf "$ES_CONFIG_DIR" > /dev/null 2>&1
            log_and_gauge "50" "$(msg 'cleanup_ra')"
            sudo rm -rf "$RA_CONFIG_DIR" > /dev/null 2>&1
            log_and_gauge "70" "$(msg 'cleanup_cores')"
            sudo rm -rf "$INSTALL_ROOT_DIR" "$LIBRETRO_CORE_PATH" > /dev/null 2>&1
            log_and_gauge "90" "$(msg 'cleanup_build')"
            sudo rm -rf "$INSTALL_BUILD_DIR" > /dev/null 2>&1
            log_and_gauge "100" "$(msg 'cleanup_done')"
        ) | dialog --clear --title "$(msg 'title_uninstall_progress')" --gauge "$(msg 'msg_cleanup_progress')" 8 60 0 2>&1 >/dev/tty

        dialog --clear --title "$(msg 'title_complete')" --msgbox "$(msg 'msg_uninstall_complete')" 8 60 2>&1 >/dev/tty
        log_msg INFO "$(msg 'uninstall_all_complete')"
    else
        log_msg INFO "$(msg 'uninstall_all_cancelled')"
    fi
}

# [7] 시스템 재부팅
function reboot_system() {
    if (dialog --clear --title "$(msg 'title_reboot')" --yesno "$(msg 'msg_reboot_confirm')" 10 60 2>&1 >/dev/tty);
 then
        log_msg WARN "$(msg 'reboot_starting')"
        dialog --clear --title "$(msg 'title_reboot_action')" --msgbox "$(msg 'msg_rebooting')" 8 60 2>&1 >/dev/tty
        sleep 3
        sudo reboot
    fi
}

# ----------------- 메인 실행 로직 -----------------
function main_ui() {
    log_msg "DEBUG" "$(msg 'main_ui_entered')"
    # 함수 호출 시점에 필요한 변수들을 로컬로 선언
    local TITLE="Retro Pangui Configuration Manager (v$__version)"
    local MENU_TITLE="$TITLE [Share: $(basename $USER_SHARE_PATH)]"
    local MENU_PROMPT="$(msg 'menu_prompt')"

    # 최초 실행 시, 핵심 의존성 설치
    install_core_dependencies

    while true; do
        # 메인 dialog 메뉴
        exec 3>&1
        CHOICE=$(dialog --clear --title "$MENU_TITLE" --menu "$MENU_PROMPT" $HEIGHT $WIDTH $CHOICE_HEIGHT \
            "install_base" "$(msg 'menu_base_install')" \
            "manage_packages" "$(msg 'menu_package_mgmt')" \
            "config_tools" "$(msg 'menu_config_tools')" \
            "update_script" "$(msg 'menu_script_update')" \
            "uninstall_all" "$(msg 'menu_uninstall_all')" \
            "reboot_system" "$(msg 'menu_reboot')" \
            "exit" "$(msg 'menu_exit')" 2>&1 1>&3)
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

    log_msg INFO "$(msg 'main_ui_exited')"
    clear
}