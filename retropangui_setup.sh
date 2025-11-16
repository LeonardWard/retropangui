#!/usr/bin/env bash

# =======================================================
# Retro Pangui Setup
# 파일명: retropangui_setup.sh
# 설명: Retro Pangui 프로젝트의 메인 런처 스크립트입니다.
#       모든 환경 변수를 설정하고, 필요한 모듈을 로드한 후,
#       메인 UI를 실행합니다.
# 사용법: sudo ./retropangui_setup.sh
# =======================================================

# --- [1] 환경 설정 및 모듈 로드 ---
# config.sh를 source하여 모든 경로와 설정 변수를 로드합니다.
# config.sh는 이 스크립트의 위치를 기준으로 ROOT_DIR을 올바르게 설정합니다.
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$MODULES_DIR/lib/log.sh"
source "$MODULES_DIR/lib/ini.sh"
source "$MODULES_DIR/lib/version.sh"
source "$MODULES_DIR/ui/menu.sh"
source "$MODULES_DIR/compat/loader.sh"
source "$MODULES_DIR/lib/packages.sh"

# 로그 파일 경로 정의 (helpers.sh가 사용하기 전에 정의)
# 로그 디렉토리는 env.sh를 통해 이미 설정되어 있습니다.
LOG_FILE="$LOG_DIR/retropangui_$(date +%Y%m%d_%H%M%S).log"
export LOG_FILE

# exec > >(tee -a "$LOG_FILE") 2>&1

# --- [2] 메인 실행 함수 ---

# Git 'dubious ownership' 오류를 자동으로 수정하는 함수
function fix_git_dubious_ownership() {
    # A harmless git command to check for the error. We check stderr.
    if ! git -C "$ROOT_DIR" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        local git_error
        git_error=$(git -C "$ROOT_DIR" status 2>&1)
        if [[ "$git_error" == *"dubious ownership"* ]]; then
            log_msg "WARN" "Git 'dubious ownership' error detected. Applying automatic fix."
            # The script is run as root (via sudo), so we apply the config to root's global git config.
            git config --global --add safe.directory "$ROOT_DIR"
            if [ $? -eq 0 ]; then
                log_msg "SUCCESS" "Successfully added '$ROOT_DIR' to git safe.directory list."
            else
                log_msg "ERROR" "Failed to apply fix for 'dubious ownership' error."
            fi
        fi
    fi
}

function main() {
    # 스크립트 초기에 Git 소유권 문제를 확인하고 수정합니다.
    fix_git_dubious_ownership

    # 커맨드라인 인자에서 언어 옵션 파싱
    for arg in "$@"; do
        case "$arg" in
            --lang=en|--english|--en)
                export RETROPANGUI_LANG="en"
                # i18n.sh 다시 로드하여 언어 재설정
                source "$MODULES_DIR/lib/i18n.sh"
                ;;
            --lang=ko|--korean|--ko|--한국어)
                export RETROPANGUI_LANG="ko"
                source "$MODULES_DIR/lib/i18n.sh"
                ;;
            --lang=*)
                echo "❌ Unsupported language. Use --lang=en or --lang=ko"
                exit 1
                ;;
        esac
    done

    load_version_from_git

    # 필수 권한 확인
    if [[ "$(id -u)" -ne 0 ]]; then
        echo "❌ 오류: 스크립트는 반드시 'sudo'로 실행되어야 합니다. 예: 'sudo $0'"
        exit 1
    fi
    ensure_log_dir

    # 플랫폼 정보 출력
    log_msg INFO "========================================="
    log_msg INFO "$(msg 'platform_info_title')"
    log_msg INFO "========================================="
    log_msg INFO "$(msg 'architecture'): $__platform_arch"
    log_msg INFO "$(msg 'detected_device'): $__device"
    log_msg INFO "$(msg 'cpu_flags'): $__default_cpu_flags"
    log_msg INFO "$(msg 'platform_flags'): ${__platform_flags[*]}"
    log_msg INFO "$(msg 'platform_config_file'): $PLATFORM_CONFIG_FILE"
    log_msg INFO "$(msg 'config_loaded'): $PLATFORM_CONFIG_LOADED"
    if [ "$PLATFORM_CONFIG_LOADED" = "yes" ]; then
        log_msg INFO "$(msg 'retroarch_version'): ${RA_VERSION:-$(msg 'latest')}"
        log_msg INFO "$(msg 'retroarch_branch'): ${RA_BRANCH:-master}"
    fi
    log_msg INFO "========================================="

    # 플랫폼 설정이 로드되지 않았을 때 처리
    if [ "$PLATFORM_CONFIG_LOADED" != "yes" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$(msg 'warning'): $(msg 'no_platform_config')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "$(msg 'detected_system_info')"
        echo "   - $(msg 'architecture'): $__platform_arch ($(uname -m))"
        echo "   - $(msg 'detected_device'): $__device"
        if [ -f /proc/device-tree/model ]; then
            echo "   - $(msg 'device_tree_model'): $(tr -d '\0' < /proc/device-tree/model)"
        fi
        echo ""
        echo "$(msg 'create_platform_config')"
        echo ""
        echo "$(msg 'step_check_configs')"
        echo "   ls $PLATFORMS_DIR/"
        echo ""
        echo "$(msg 'step_copy_similar')"
        echo "   $(msg 'arm64_device_case')"
        echo "   cp $PLATFORMS_DIR/odroidc5.conf $PLATFORMS_DIR/mynewboard.conf"
        echo ""
        echo "   $(msg 'armv7_device_case')"
        echo "   cp $PLATFORMS_DIR/odroidxu4.conf $PLATFORMS_DIR/mynewboard.conf"
        echo ""
        echo "$(msg 'step_add_detection')"
        echo "   nano $ROOT_DIR/config.sh"
        echo ""
        echo "   case \"\$model\" in"
        echo "       *\"Your Board Name\"*) echo \"mynewboard\"; return;;"
        echo "   esac"
        echo ""
        echo "$(msg 'step_modify_config')"
        echo "   nano $PLATFORMS_DIR/mynewboard.conf"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # 사용자에게 계속 진행 여부 확인
        if [ -f "$PLATFORMS_DIR/$__platform_arch.conf" ]; then
            read -p "$(msg 'continue_with_generic') ($(msg 'using_generic_config') $__platform_arch.conf) [y/N]: " -n 1 -r
        else
            read -p "$(msg 'continue_without_config') [y/N]: " -n 1 -r
        fi
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_msg INFO "$(msg 'user_cancelled')"
            exit 1
        fi

        # 아키텍처별 기본 설정이 있으면 사용
        if [ -f "$PLATFORMS_DIR/$__platform_arch.conf" ]; then
            log_msg WARN "$(msg 'continuing_with_generic') $__platform_arch $(msg 'config_proceeding')"
            source "$PLATFORMS_DIR/$__platform_arch.conf"
            export PLATFORM_CONFIG_LOADED="yes"
            export PLATFORM_CONFIG_FILE="$__platform_arch.conf (generic)"
        else
            log_msg WARN "$(msg 'continuing_without_config')"
        fi
    fi

    # 스크립트 실행 권한 부여
    log_msg INFO "자신과 하위 스크립트의 실행 권한 확인 및 부여"
    find "$ROOT_DIR" -type f -name "*.sh" -exec chmod +x {} \;
    log_msg SUCCESS "모든 .sh 파일에 실행 권한이 부여되었습니다."

    # UI를 실행할지 여부를 결정하는 플래그
    local run_ui=true
    local args=("$@") # 원본 인자를 복사
    if [[ "${args[0]}" == "--no-ui" ]]; then
        run_ui=false
        args=("${args[@]:1}") # --no-ui 플래그 제거
    fi

    if $run_ui; then
        # 메인 UI 실행
        log_msg INFO "🚀 Retro Pangui 설정 관리자를 시작합니다..."
        main_ui "${args[@]}"
        exit 0 # UI가 실행되었을 때만 스크립트를 종료
    else
        log_msg INFO "UI 없이 환경만 설정합니다."
        # UI가 실행되지 않으면, install_module이 실행될 수 있도록 종료하지 않고 반환
    fi
}

# --- [3] 스크립트 실행 ---
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ "$1" == "install_module" && -n "$2" && -n "$3" ]]; then
        # 디버깅을 위한 install_module 직접 호출
        main --no-ui # UI 없이 환경만 설정
        install_module "$2" "$3"
    else
        main "$@"
    fi
fi
