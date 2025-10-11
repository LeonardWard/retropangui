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

    git_Pull_Or_Clone "$RETROPIE_SETUP_GIT_URL" "$TEMP_DIR_BASE/$EXT_FOLDER" --depth=1

    # retropie_setup 디렉토리가 없으면 생성
    mkdir -p "$RETROPIE_SETUP_DIR"

    # 원본 파일들을 복사하여 덮어쓰기
    cp -r "$TEMP_DIR_BASE/$EXT_FOLDER/scriptmodules" "$RETROPIE_SETUP_DIR"
    cp -r "$TEMP_DIR_BASE/$EXT_FOLDER/retropie_packages.sh" "$RETROPIE_SETUP_DIR"
    cp -r "$TEMP_DIR_BASE/$EXT_FOLDER/retropie_setup.sh" "$RETROPIE_SETUP_DIR"
    log_msg SUCCESS "RetroPie 스크립트 모듈을 성공적으로 복사/업데이트했습니다."
}

# ----------------- 메인 메뉴 함수 (Main Menu Functions) -----------------

# [1] Base System 설치 (모듈 호출)
function run_base_system_install() {
    log_msg "DEBUG" "ui.sh: run_base_system_install 함수 진입."
    if (whiptail --title "Base System 설치" --yesno "RetroArch/EmulationStation 설치 및 Recalbox 환경 구축/패치를 진행하시겠습니까?\n\n(참고: 설치 진행 상황은 터미널에 직접 출력됩니다.)" 12 60); then
        
        log_msg INFO "Base System 설치 모듈(system_install.sh)을 실행합니다."
        
        log_msg INFO "========================================================"
        log_msg INFO "   🚀 Retro Pangui Base System 설치를 시작합니다..."
        log_msg INFO "   (자세한 빌드 과정이 이어서 출력됩니다.)"
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

# [2] Base System 업데이트 (간단 로직)
function run_base_system_update() {
    local UPDATE_STATUS="업데이트 가능 (v0.2)" 
    if (whiptail --title "Base System 업데이트" --yesno "업데이트 상태: $UPDATE_STATUS\n업데이트를 진행하시겠습니까?" 10 60); then
        log_msg INFO "Base System 업데이트 로직 실행 시작."
        whiptail --title "업데이트 진행" --msgbox "Base System 업데이트 로직이 실행되었습니다. (추가 로직 필요)" 8 60
    fi
}

# [3] 패키지 관리 메뉴 (서브 메뉴)
function package_management_menu() {
    log_msg INFO "패키지 관리 메뉴에 진입했습니다."
    while true; do
        CHOICE=$(whiptail --title "패키지 관리" --menu "관리할 패키지 종류를 선택하세요." 18 80 10 \
            "1" "Core (RetroArch/EmulationStation 관리)" \
            "2" "Main (RetroArch 라이브러리 및 코어 관리)" \
            "3" "Option (커스텀/기타 라이브러리 관리)" \
            "4" "드라이버 (xpad, xdrv 등 관리)" \
            "5" "뒤로"  3>&1 1>&2 2>&3)
        
        [ $? -eq 0 ] && [ "$CHOICE" == "5" ] && break || whiptail --title "알림" --msgbox "세부 관리 로직은 추가 구현이 필요합니다." 8 60
        [ $? -ne 0 ] && break
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

# [5] 스크립트 업데이트 (간단 로직)
function update_script() {
    local UPDATE_STATUS="업데이트 가능 (v$__version -> v0.2)"
    if (whiptail --title "스크립트 업데이트" --yesno "현재 버전: v$__version\n업데이트 상태: $UPDATE_STATUS\n\n업데이트를 진행하시겠습니까?" 10 60); then
        log_msg INFO "retropangui 스크립트 업데이트 로직 실행 시작."
        whiptail --title "업데이트 진행" --msgbox "스크립트 업데이트 로직이 실행되었습니다. (추가 로직 필요)" 8 60
    fi
}

# [6] 전부 설치 제거 (소스 빌드 후 설정 파일 정리 로직)
function uninstall_all() {
    if (whiptail --title "설정 파일 정리" --yesno "Base System의 사용자 설정 파일만 모두 제거합니다. (Share 폴더 제외)\n소스 빌드된 바이너리 파일은 시스템에서 직접 제거해야 합니다.\n\n계속하시겠습니까?" 10 70); then
        log_msg INFO "전부 설치 제거 (설정 파일 정리) 시작."
        (
            echo "30"; echo "### EmulationStation 설정 디렉토리 제거 중..."; 
            echo "70"; echo "### RetroArch 설정 디렉토리 제거 중..."; 
            sudo rm -rf "$ES_CONFIG_DIR" "$RA_CONFIG_DIR" > /dev/null 2>&1
            echo "100"; echo "### 정리 완료.";
        ) | whiptail --title "정리 진행" --gauge "사용자 설정 파일 정리 중..." 6 50 0
        
        whiptail --title "완료" --msgbox "사용자 설정 파일 제거가 완료되었습니다." 8 60
        log_msg INFO "설정 파일 정리 완료: $ES_CONFIG_DIR, $RA_CONFIG_DIR 디렉토리 제거됨."
    else
        log_msg INFO "설정 파일 정리가 사용자 요청에 의해 취소되었습니다."
    fi
}

# [7] 시스템 재부팅
function reboot_system() {
    if (whiptail --title "시스템 재부팅" --yesno "시스템을 지금 바로 재부팅하시겠습니까?" 10 60); then
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
            "2" "Base System 업데이트" \
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
                2) run_base_system_update ;; 
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
