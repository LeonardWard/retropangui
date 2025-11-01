#!/usr/bin/env bash

# =======================================================
# Retro Pangui UI Library
# 파일명: ui.sh
# 설명: Retro Pangui의 모든 whiptail 메뉴 및 UI 관련 함수를 정의합니다.
#       이 파일은 실행 파일이 아니며, 메인 스크립트가 source하여 사용합니다.
# =======================================================

# ----------------- 초기화 함수 (Initialization Function) -----------------
# 핵심 의존성(dependency) 패키지 설치 및 모듈 다운로드를 확인하고 진행하는 함수
function install_core_dependencies() {
    # whiptail, git 등 스크립트 실행에 필요한 기본 유틸리티 목록
    local CORE_DEPS=("whiptail" "dialog" "git" "wget" "curl" "unzip")
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

# ----------------- 메인 메뉴 함수 (Main Menu Functions) -----------------

# [1] Base System 설치 (모듈 호출)
function run_base_system_install() {
    log_msg "DEBUG" "ui.sh: run_base_system_install 함수 진입."
    if (whiptail --title "Base System 설치" --yesno "RetroArch/EmulationStation 설치 및 Recalbox 환경 구축/패치를 진행하시겠습니까?\n\n(참고: 설치 진행 상황은 터미널에 직접 출력됩니다.)" 12 60);
 then
        
        log_msg INFO "Base System 설치 모듈(system_install.sh)을 실행합니다."
        
        log_msg INFO "========================================================"
        log_msg INFO "   🚀 Retro Pangui Base System 설치를 시작합니다..."
        log_msg INFO "========================================================"
        
        # system_install.sh 모듈을 source하여 실행
        source "$MODULES_DIR/system_install.sh"
        local INSTALL_STATUS=$?
        
        log_msg INFO "\n========================================================"
        
        if [ $INSTALL_STATUS -eq 0 ]; then
            whiptail --title "✅ 설치 성공" --msgbox "Base System 설치 및 환경 패치가 완료되었습니다." 10 60
            log_msg INFO "Base System 설치가 성공적으로 완료되었습니다."
        else
            whiptail --title "❌ 설치 실패" --msgbox "설치 모듈 실행 중 오류가 발생했습니다. 상세한 실패 원인은 로그 파일을 확인하십시오: $LOG_FILE" 10 60
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
            whiptail --title "정보" --msgbox "이 섹션에는 현재 플랫폼에서 설치 가능한 패키지가 없습니다." 8 70
            return
        fi

        local CHOICE
        CHOICE=$(whiptail --title "$section_title" --menu "패키지를 선택하세요 (설치됨: ✔)." "$box_height" "$box_width" "$list_height" "${options[@]}" 3>&1 1>&2 2>&3)

        if [ $? -eq 0 ]; then
            package_action_menu "$CHOICE" "${module_info["$CHOICE,type"]}" "${module_info["$CHOICE,status"]}"
        else
            break # 뒤로 가기 또는 ESC
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
        choice=$(whiptail --title "패키지: $module_id" --menu "상태: $status_text\n\n수행할 작업을 선택하세요." 18 78 10 \
            "install"  "패키지 설치/업데이트" \
            "remove"   "패키지 제거" \
            "info"     "패키지 정보 보기" \
            "back"     "뒤로" 3>&1 1>&2 2>&3)

        local exitstatus=$?
        if [ $exitstatus -ne 0 ]; then
            break
        fi

        case "$choice" in
            install)
                if [[ "$is_installed" == "ON" ]]; then
                    if !(whiptail --title "경고" --yesno "이 패키지는 이미 설치되어 있습니다.\n다시 설치(업데이트) 하시겠습니까?" 10 60); then
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
                    whiptail --title "오류" --msgbox "이 패키지는 설치되어 있지 않습니다." 8 78
                    continue
                fi
                if (whiptail --title "확인" --yesno "정말로 '$module_id' 패키지를 제거하시겠습니까?\n이 작업은 되돌릴 수 없습니다." 10 60); then
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
    done
}

function show_package_info() {
    local module_id="$1"
    local module_type="$2"

    log_msg INFO "정보 보기: $module_id"

    local script_path="$MODULES_DIR/retropie_setup/scriptmodules/$module_type/$module_id.sh"
    if [[ ! -f "$script_path" ]]; then
        whiptail --title "오류" --msgbox "스크립트 파일을 찾을 수 없습니다:\n$script_path" 8 78
        return
    fi

    # romdir, biosdir 변수를 설정하고 서브셸에서 스크립트를 source하여 변수가 확장된 help_text를 가져옴
    local help_text=$(romdir="$USER_ROMS_PATH"; biosdir="$USER_BIOS_PATH"; source "$script_path"; echo "$rp_module_help")

    if [[ -z "$help_text" ]]; then
        help_text="이 패키지에 대한 정보가 없습니다."
    fi

    whiptail --title "정보: $module_id" --msgbox "$help_text" 20 78
}

# 새로운 패키지 관리 메인 메뉴
function package_management_menu() {
    local choice
    while true; do
        choice=$(whiptail --title "패키지 관리" --menu "관리할 패키지 섹션을 선택하세요." 18 78 10 \
            "core"     "코어 패키지" \
            "main"     "메인 패키지" \
            "opt"      "선택적 패키지" \
            "exp"      "실험적 패키지" \
            "driver"   "드라이버" \
            "config"   "설정 작업" \
            "depends"  "의존성" \
            "back"     "뒤로" 3>&1 1>&2 2>&3)

        local exitstatus=$?
        if [ $exitstatus -ne 0 ]; then
            break
        fi

        case "$choice" in
            core|main|opt|exp|driver)
                manage_packages_by_section "$choice 패키지" "$choice"
                ;;
            config|depends)
                whiptail --title "알림" --msgbox "이 섹션의 관리는 아직 지원되지 않습니다." 8 78
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
        CHOICE=$(whiptail --title "설정 / 기타 도구" --menu "실행할 도구를 선택하세요." 18 80 10 \
            "1" "시스템 시작 시 ES 실행 스크립트 설치" \
            "2" "삼바(Samba) 설정 및 활성화" \
            "3" "Share 폴더 경로 설정 (현재: $USER_SHARE_PATH)" \
            "4" "뒤로"  3>&1 1>&2 2>&3)

        if [ $? -eq 0 ]; then
            case $CHOICE in
                1|2) log_msg INFO "설정/도구 항목 $CHOICE 선택. 로직 미구현."
                    whiptail --title "알림" --msgbox "세부 설정 로직은 추가 구현이 필요합니다." 8 60 ;;
                3) set_share_path ;; 
                4) break ;; 
            esac
        else
            break
        fi
    done
}

# Share 폴더 경로 설정 함수 (경로 변경 로직)
function set_share_path() {
    log_msg INFO "Share 폴더 경로 설정 시작 (현재: $USER_SHARE_PATH)"
    local NEW_PATH=$(whiptail --title "Retro Pangui Share 경로 설정" --inputbox \
        "Retro Pangui 'share' 폴더의 절대 경로를 입력하세요.\n(현재 경로: $USER_SHARE_PATH)" 10 80 "$USER_SHARE_PATH" 3>&1 1>&2 2>&3)
    
    local exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ -d "$NEW_PATH" ] || (whiptail --title "경로 오류" --yesno "경로 $NEW_PATH 가 존재하지 않습니다. 새로 생성하시겠습니까?" 8 80 && sudo mkdir -p "$NEW_PATH"); then
            # config.sh 파일의 USER_SHARE_PATH 변수를 업데이트합니다.
            local CONFIG_FILE="$MODULES_DIR/config.sh"
            
            # func.sh에 정의된 config_set 함수를 사용하여 안전하게 변수 변경
            config_set "USER_SHARE_PATH" "$NEW_PATH" "$CONFIG_FILE"

            # 현재 실행중인 스크립트의 메모리 변수도 업데이트
            USER_SHARE_PATH="$NEW_PATH"

            whiptail --title "경로 설정 완료" --msgbox "Retro Pangui Share 경로가 $USER_SHARE_PATH 로 설정되었습니다." 8 80
            log_msg INFO "Share 경로가 $USER_SHARE_PATH 로 성공적으로 변경되었습니다."
        else
            log_msg WARN "Share 경로 설정이 취소되거나 경로 생성에 실패했습니다."
        fi
    fi
}

# [5] 스크립트 업데이트 (Git 기반)
function update_script() {
    log_msg INFO "스크립트 업데이트 확인 중..."
    whiptail --title "업데이트 확인" --infobox "원격 저장소에서 최신 버전 정보를 가져오는 중..." 8 60

    # 원격 저장소의 태그 목록을 가져옵니다.
    local remote_tags=$(git ls-remote --tags origin | awk '{print $2}' | grep -o 'v[0-9]\+\.[0-9]\+\(\.[0-9]\+\)*$' | sort -V | tail -n 1)

    if [ -z "$remote_tags" ]; then
        log_msg WARN "원격 버전(태그) 정보를 찾을 수 없습니다. 업데이트를 진행할 수 없습니다."
        whiptail --title "알림" --msgbox "확인 가능한 원격 버전 정보(태그)가 없습니다. 업데이트를 진행할 수 없습니다." 8 78
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

        if (whiptail --title "스크립트 업데이트" --yesno "새로운 버전의 스크립트를 사용할 수 있습니다.\n\n현재 버전: v${local_version_num}\n최신 버전: ${__rpg_latest_remote_version}\n\n업데이트를 진행하시겠습니까?" 12 60); then
            log_msg INFO "retropangui 스크립트 업데이트 시작."
            
            local stashed=false
            if [ -n "$(git status --porcelain)" ]; then
                log_msg INFO "로컬 변경사항을 임시 저장합니다."
                if ! git stash push -u -m "RetroPangui-Auto-Stash-Before-Update"; then
                    log_msg ERROR "로컬 변경사항 임시 저장 실패."
                    whiptail --title "업데이트 실패" --msgbox "로컬 변경사항을 임시 저장하는 데 실패했습니다. 업데이트를 진행할 수 없습니다." 10 78
                    return
                fi
                stashed=true
            fi

            log_msg INFO "원격 저장소에서 업데이트를 가져옵니다."
            if ! git pull --rebase origin main > >(tee -a "$LOG_FILE") 2>&1; then
                log_msg ERROR "업데이트 실패 ('git pull --rebase' 실패)."
                whiptail --title "업데이트 실패" --msgbox "업데이트를 가져오는 데 실패했습니다. 자세한 내용은 로그를 확인하세요." 8 78
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
                    whiptail --title "업데이트 완료 (주의)" --msgbox "스크립트가 성공적으로 업데이트되었습니다.\n\n하지만, 로컬 수정사항 중 일부를 자동으로 재적용할 수 없었습니다. 변경하신 내용은 안전하게 백업되어 있으니, 전문가의 도움이 필요할 수 있습니다. (가장 최근 stash 확인)" 12 78
                else
                    log_msg SUCCESS "로컬 변경사항을 성공적으로 다시 적용했습니다."
                    whiptail --title "업데이트 완료" --msgbox "스크립트가 성공적으로 업데이트되었으며, 로컬 변경사항도 유지되었습니다." 10 78
                    whiptail --title "안내" --msgbox "RetroArch 등 개별 구성요소의 업데이트는 '패키지 관리' 메뉴에서 확인하세요." 10 78
                fi
            else
                whiptail --title "업데이트 완료" --msgbox "스크립트가 성공적으로 업데이트되었습니다." 8 78
                whiptail --title "안내" --msgbox "RetroArch 등 개별 구성요소의 업데이트는 '패키지 관리' 메뉴에서 확인하세요." 10 78
            fi

        else
            log_msg INFO "스크립트 업데이트가 사용자에 의해 취소되었습니다."
        fi
    else
        log_msg INFO "스크립트가 이미 최신 버전입니다."
        whiptail --title "스크립트 업데이트" --msgbox "현재 최신 버전의 스크립트를 사용하고 있습니다.\n\n현재 버전: v${local_version_num}" 10 60
    fi
}

# [6] 전부 설치 제거 (Share 폴더 제외)
function uninstall_all() {
    if (whiptail --title "전체 설치 제거" --yesno "Retro Pangui가 생성한 모든 설정, 로그, 빌드 파일, 설치된 코어 및 에뮬레이터를 제거합니다. (Share 폴더 제외)\n\n이 작업은 되돌릴 수 없습니다. 정말로 계속하시겠습니까?" 12 70);
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
        ) | whiptail --title "전체 제거 진행" --gauge "생성된 파일 정리 중..." 8 60 0
        
        whiptail --title "완료" --msgbox "모든 생성 파일(Share 폴더 제외) 제거가 완료되었습니다." 8 60
        log_msg INFO "전체 설치 제거 완료."
    else
        log_msg INFO "전체 설치 제거가 사용자에 의해 취소되었습니다."
    fi
}

# [7] 시스템 재부팅
function reboot_system() {
    if (whiptail --title "시스템 재부팅" --yesno "시스템을 지금 바로 재부팅하시겠습니까?" 10 60);
 then
        log_msg WARN "시스템 재부팅을 시작합니다."
        whiptail --title "재부팅" --msgbox "시스템을 3초 후 재부팅합니다." 8 60
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
        # 메인 whiptail 메뉴
        CHOICE=$(whiptail --title "$MENU_TITLE" --menu "$MENU_PROMPT" $HEIGHT $WIDTH $CHOICE_HEIGHT \
            "1" "Base System 설치" \
            "3" "패키지 관리 (Core/Main/Driver)" \
            "4" "설정 / 기타 도구" \
            "5" "스크립트 업데이트" \
            "6" "전부 설치 제거 (Share 폴더 제외)" \
            "7" "시스템 재부팅" \
            "8" "종료" 3>&1 1>&2 2>&3)

        local exitstatus=$?
        if [ $exitstatus -eq 0 ]; then
            case $CHOICE in
                1) run_base_system_install ;; 
                3) package_management_menu ;; 
                4) config_tools_menu ;; 
                5) update_script ;; 
                6) uninstall_all ;; 
                7) reboot_system ;; 
                8) break ;; 
            esac
        else
            log_msg INFO "Retro Pangui Configuration Manager 메뉴에서 취소/종료."
            break
        fi
    done
    
    log_msg INFO "Retro Pangui Configuration Manager 종료."
    clear
}