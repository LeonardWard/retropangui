#!/usr/bin/env bash

# =======================================================
# Retro Pangui Core Handler
# 파일명: retropangui_core.sh
# 설명: Retro Pangui의 환경을 정의하고, 권한을 확인하며, whiptail 메뉴를 표시합니다.
# 모든 복잡한 설치 로직은 'scriptmodules' 파일로 분리되었습니다.
# =======================================================

# --- [0] 사용자 및 그룹 권한 설정 (최상단) ---
# 이 블록은 config.sh를 로드하기 전에, 권한 관련 로직을 처리해야 하므로 여기에 유지합니다.
if [[ -z "$__user" ]]; then
    __user="$SUDO_USER"
    [[ -z "$__user" ]] && __user="$(id -un)"
fi
user="$__user"

# 스크립트 경로 설정
SCRIPT_DIR="$(dirname "$0")"
SCRIPT_DIR="$(cd "$SCRIPT_DIR" && pwd)"
MODULES_DIR="$SCRIPT_DIR/scriptmodules"

# ------------------------------------------------------------------
# 💡 핵심: 모든 전역 변수를 config.sh에서 불러옵니다.
# ------------------------------------------------------------------
source "$MODULES_DIR/config.sh" 

# --- [1] 경로 정의 (config.sh 변수 기반으로 정의) ---
# config.sh가 로드된 후, __user 변수를 사용하여 동적 경로를 완성합니다.
USER_HOME="$(eval echo ~$__user)"

# --- [2] 로그 파일 경로 정의 (config.sh의 LOG_DIR 사용) ---
LOG_FILE="$LOG_DIR/retropangui_setup_$(date +%Y%m%d_%H%M%S).log"

# --- [3] 필수 권한 확인 ---
if [[ "$(id -u)" -ne 0 ]]; then
    echo "❌ 오류: 스크립트는 반드시 'sudo'로 실행되어야 합니다. 예: 'sudo $0'"
    exit 1
fi

# --- [4] 라이브러리 및 도우미 로드 ---
# log_msg, command_exists 함수를 포함한 helpers.sh 모듈 로드 (필수)
source "$MODULES_DIR/helpers.sh" 

# --- [5] Whiptail/메뉴 설정 (config.sh 변수 사용) ---
TITLE="Retro Pangui Configuration Manager (v$__version)"
MENU_TITLE="$TITLE [Share: $(basename $USER_SHARE_PATH)]"
MENU_PROMPT="메뉴를 선택하세요.\n(Share 경로 전체: $USER_SHARE_PATH)"

# ----------------- 초기화 함수 (Initialization Function) -----------------
# 핵심 의존성(dependency) 패키지 설치 및 모듈 다운로드를 확인하고 진행하는 함수
install_core_dependencies() {
    # 로그 디렉토리 생성 (최초 실행 시)
    sudo mkdir -p "$LOG_DIR"
    log_msg INFO "로그 파일 경로 설정 완료: $LOG_FILE"

    # whiptail, git, svn 등 스크립트 실행에 필요한 기본 유틸리티 목록
    local CORE_DEPS=("whiptail" "dialog" "git" "wget" "curl" "unzip" "subversion")
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

        sudo apt update
        sudo apt install -y "${MISSING_DEPS[@]}"

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

    local EMULATORS_DIR="$MODULES_DIR/emulators"
    local LIBRETROCORES_DIR="$MODULES_DIR/libretrocores"
    local RETROPIE_EMULATORS_URL="https://github.com/RetroPie/RetroPie-Setup/trunk/scriptmodules/emulators"
    local RETROPIE_LIBRETRO_URL="https://github.com/RetroPie/RetroPie-Setup/trunk/scriptmodules/libretrocores"

    # emulators 디렉토리 다운로드
    if [ ! -d "$EMULATORS_DIR" ]; then
        log_msg INFO "'emulators' 스크립트 모듈을 다운로드합니다..."
        if sudo svn export --force "$RETROPIE_EMULATORS_URL" "$EMULATORS_DIR"; then
            sudo chown -R "$__user:$__user" "$EMULATORS_DIR"
            log_msg INFO "'emulators' 모듈 다운로드 완료."
        else
            log_msg ERROR "'emulators' 모듈 다운로드에 실패했습니다."
        fi
    else
        log_msg INFO "'emulators' 스크립트 모듈이 이미 존재합니다."
    fi

    # libretrocores 디렉토리 다운로드
    if [ ! -d "$LIBRETROCORES_DIR" ]; then
        log_msg INFO "'libretrocores' 스크립트 모듈을 다운로드합니다..."
        if sudo svn export --force "$RETROPIE_LIBRETRO_URL" "$LIBRETROCORES_DIR"; then
            sudo chown -R "$__user:$__user" "$LIBRETROCORES_DIR"
            log_msg INFO "'libretrocores' 모듈 다운로드 완료."
        else
            log_msg ERROR "'libretrocores' 모듈 다운로드에 실패했습니다."
        fi
    else
        log_msg INFO "'libretrocores' 스크립트 모듈이 이미 존재합니다."
    fi
}

# ----------------- 메인 메뉴 기능 함수 (Main Menu Functions) -----------------

# [1] Base System 설치 (모듈 호출)
run_base_system_install() {
    if (whiptail --title "Base System 설치" --yesno "RetroArch/EmulationStation 설치 및 Recalbox 환경 구축/패치를 진행하시겠습니까?\n\n(참고: 설치 진행 상황은 터미널에 직접 출력됩니다.)" 12 60); then
        
        log_msg INFO "Base System 설치 모듈(system_install.sh)을 실행합니다."
        
        # whiptail을 닫고 터미널 출력 시작 메시지
        echo -e "\n========================================================"
        echo "   🚀 Retro Pangui Base System 설치를 시작합니다..."
        echo "   (자세한 빌드 과정이 이어서 출력됩니다.)"
        echo "========================================================"
        
        # 💡 인수 전달: 모든 핵심 경로와 Git URL을 system_install.sh 모듈에 전달
        bash "$MODULES_DIR/system_install.sh"        
        INSTALL_STATUS=$?
        
        echo -e "\n========================================================"
        
        # 설치 결과에 따른 whiptail 메시지 분기
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
run_base_system_update() {
    local UPDATE_STATUS="업데이트 가능 (v0.2)" 
    if (whiptail --title "Base System 업데이트" --yesno "업데이트 상태: $UPDATE_STATUS\n업데이트를 진행하시겠습니까?" 10 60); then
        log_msg INFO "Base System 업데이트 로직 실행 시작."
        whiptail --title "업데이트 진행" --msgbox "Base System 업데이트 로직이 실행되었습니다. (추가 로직 필요)" 8 60
    fi
}

# [3] 패키지 관리 메뉴 (서브 메뉴)
package_management_menu() {
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
config_tools_menu() {
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
set_share_path() {
    log_msg INFO "Share 폴더 경로 설정 시작 (현재: $USER_SHARE_PATH)"
    NEW_PATH=$(whiptail --title "Retro Pangui Share 경로 설정" --inputbox \
        "Retro Pangui 'share' 폴더의 절대 경로를 입력하세요.\n(현재 경로: $USER_SHARE_PATH)" 10 80 "$USER_SHARE_PATH" 3>&1 1>&2 2>&3)
    
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ -d "$NEW_PATH" ] || (whiptail --title "경로 오류" --yesno "경로 $NEW_PATH 가 존재하지 않습니다. 새로 생성하시겠습니까?" 8 80 && sudo mkdir -p "$NEW_PATH"); then
            # config.sh 파일의 USER_SHARE_PATH 변수를 업데이트해야 합니다.
            local CONFIG_FILE="$MODULES_DIR/config.sh"
            local NEW_VAR="USER_SHARE_PATH" 

            # 1. 현재 스크립트의 메모리 변수를 업데이트합니다.
            USER_SHARE_PATH="$NEW_PATH"
            
            # 2. config.sh 파일을 수정합니다.
            # config.sh에서 'USER_SHARE_PATH='로 시작하는 모든 줄을 찾아서 변경합니다.
            if grep -q "^$NEW_VAR=" "$CONFIG_FILE"; then
                # 이미 변수 정의가 있으면 수정
                sudo sed -i "/^$NEW_VAR=/c\\$NEW_VAR=\"$USER_SHARE_PATH\"" "$CONFIG_FILE"
            elif grep -q "^# $NEW_VAR=" "$CONFIG_FILE"; then
                # 주석 처리된 변수 정의가 있으면 주석 해제 후 수정
                sudo sed -i "/^# $NEW_VAR=/c\\$NEW_VAR=\"$USER_SHARE_PATH\"" "$CONFIG_FILE"
            else
                # 파일 끝에 추가
                echo "$NEW_VAR=\"$USER_SHARE_PATH\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
            fi

            whiptail --title "경로 설정 완료" --msgbox "Retro Pangui Share 경로가 $USER_SHARE_PATH 로 설정되었습니다." 8 80
            log_msg INFO "Share 경로가 $USER_SHARE_PATH 로 성공적으로 변경되었습니다."
        else
            log_msg WARN "Share 경로 설정이 취소되거나 경로 생성에 실패했습니다."
        fi
    fi
}

# [5] 스크립트 업데이트 (간단 로직)
update_script() {
    local UPDATE_STATUS="업데이트 가능 (v$__version -> v0.2)"
    if (whiptail --title "스크립트 업데이트" --yesno "현재 버전: v$__version\n업데이트 상태: $UPDATE_STATUS\n\n업데이트를 진행하시겠습니까?" 10 60); then
        log_msg INFO "retropangui_core.sh 업데이트 로직 실행 시작."
        whiptail --title "업데이트 진행" --msgbox "스크립트 업데이트 로직이 실행되었습니다. (추가 로직 필요)" 8 60
    fi
}

# [6] 전부 설치 제거 (소스 빌드 후 설정 파일 정리 로직)
uninstall_all() {
    if (whiptail --title "설정 파일 정리" --yesno "Base System의 사용자 설정 파일만 모두 제거합니다. (Share 폴더 제외)\n소스 빌드된 바이너리 파일은 시스템에서 직접 제거해야 합니다.\n\n계속하시겠습니까?" 10 70); then
        log_msg INFO "전부 설치 제거 (설정 파일 정리) 시작."
        (
            echo "30"; echo "### EmulationStation 설정 디렉토리 제거 중..."; 
            
            echo "70"; echo "### RetroArch 설정 디렉토리 제거 중..."; 
            
            # 사용자 설정 디렉토리만 안전하게 제거합니다.
            echo "90"; echo "### 사용자 설정 디렉토리 제거 중..."; 
            
            # rm 명령의 출력을 완전히 무시하여 whiptail 게이지를 깨지 않도록 수정
            sudo rm -rf "$ES_CONFIG_DIR" "$RA_CONFIG_DIR" > /dev/null 2>&1
            
            echo "100"; echo "### 정리 완료.";
        ) | whiptail --title "정리 진행" --gauge "사용자 설정 파일 정리 중..." 6 50 0
        
        whiptail --title "완료" --msgbox "사용자 설정 파일 제거가 완료되었습니다.\n(소스 빌드된 바이너리 제거는 수동으로 진행해야 합니다.)" 8 60
        log_msg INFO "설정 파일 정리 완료: $ES_CONFIG_DIR, $RA_CONFIG_DIR 디렉토리 제거됨."
    else
        log_msg INFO "설정 파일 정리가 사용자 요청에 의해 취소되었습니다."
    fi
}

# [7] 시스템 재부팅
reboot_system() {
    if (whiptail --title "시스템 재부팅" --yesno "시스템을 지금 바로 재부팅하시겠습니까?" 10 60); then
        log_msg WARN "시스템 재부팅을 시작합니다."
        whiptail --title "재부팅" --msgbox "시스템을 3초 후 재부팅합니다." 8 60
        sleep 3
        sudo reboot
    fi
}

# ----------------- 메인 실행 로직 -----------------

if [[ $# -gt 0 ]]; then
    if [[ "$1" == "setup" && "$2" == "gui" ]]; then
        
        install_core_dependencies 
        
        EXIT_PROGRAM=0 # 종료 플래그 추가

        while true; do
            # 메인 whiptail 메뉴
            CHOICE=$(whiptail --title "$MENU_TITLE" --menu "$MENU_PROMPT" $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "1" "Base System 설치" \
                "2" "Base System 업데이트" \
                "3" "패키지 관리 (Core/Main/Driver)" \
                "4" "설정 / 기타 도구" \
                "5" "retropangui_core.sh 업데이트" \
                "6" "전부 설치 제거 (/Share는 그대로 놔둠)" \
                "7" "시스템 재부팅" \
                "8" "종료" 3>&1 1>&2 2>&3)

            exitstatus=$?
            if [ $exitstatus -eq 0 ]; then
                case $CHOICE in
                    1) run_base_system_install ;;
                    2) run_base_system_update ;;
                    3) package_management_menu ;;
                    4) config_tools_menu ;;
                    5) update_script ;;
                    6) uninstall_all ;;
                    7) reboot_system ;;
                    8) EXIT_PROGRAM=1 ; break ;; # 💡 플래그 설정 후 루프 종료
                esac
            else
                log_msg INFO "Retro Pangui Configuration Manager 메뉴에서 취소/종료."
                EXIT_PROGRAM=1 # ESC/Cancel 시에도 종료 플래그 설정
                break
            fi
        done
        
        # 💡 루프 탈출 후 종료 플래그 확인
        if [ $EXIT_PROGRAM -eq 1 ]; then
            log_msg INFO "Retro Pangui Configuration Manager 종료."
            clear # 💡 터미널 정리 후
            exit 0 # 💡 스크립트 최종 종료
        fi

    else
        echo "⚠️ 지원되는 인자: 'setup gui' (whiptail 메뉴 실행)"
    fi
else
    echo "사용법: $0 setup gui"
fi

exit 0
