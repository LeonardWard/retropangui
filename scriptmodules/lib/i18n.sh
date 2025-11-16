#!/usr/bin/env bash

# =======================================================
# Retro Pangui Internationalization (i18n)
# 파일명: scriptmodules/lib/i18n.sh
# 설명: 다국어 지원 (한국어/영어)
# =======================================================

# 언어 감지
detect_language() {
    # 1순위: 환경 변수 RETROPANGUI_LANG
    if [ -n "$RETROPANGUI_LANG" ]; then
        case "$RETROPANGUI_LANG" in
            ko|korean|한국어) echo "ko"; return;;
            en|english|영어) echo "en"; return;;
            *) echo "en"; return;;  # 잘못된 값은 영어로
        esac
    fi

    # 2순위: 시스템 로케일
    local lang="${LANG:-en_US.UTF-8}"

    # 한국어 로케일 감지
    if [[ "$lang" =~ ^ko ]]; then
        echo "ko"
    else
        echo "en"
    fi
}

# 언어 설정
__lang=$(detect_language)
export __lang

# 다국어 메시지 함수
msg() {
    local key="$1"

    if [ "$__lang" = "ko" ]; then
        case "$key" in
            # 플랫폼 정보
            "platform_info_title") echo "플랫폼 정보";;
            "architecture") echo "아키텍처";;
            "detected_device") echo "감지된 기기";;
            "cpu_flags") echo "CPU 플래그";;
            "platform_flags") echo "플랫폼 플래그";;
            "platform_config_file") echo "플랫폼 설정 파일";;
            "config_loaded") echo "설정 로드 상태";;
            "retroarch_version") echo "RetroArch 버전";;
            "retroarch_branch") echo "RetroArch 브랜치";;

            # 경고 및 오류
            "warning") echo "⚠️  경고";;
            "error") echo "❌ 오류";;
            "no_platform_config") echo "플랫폼 설정 파일을 찾을 수 없습니다!";;
            "detected_system_info") echo "📋 감지된 시스템 정보:";;
            "device_tree_model") echo "Device-tree 모델";;

            # 플랫폼 설정 안내
            "create_platform_config") echo "📝 플랫폼 설정 파일을 생성해야 합니다:";;
            "step_check_configs") echo "1️⃣  기존 설정 파일 확인:";;
            "step_copy_similar") echo "2️⃣  가장 유사한 설정 파일을 복사:";;
            "step_add_detection") echo "3️⃣  config.sh의 detect_device() 함수에 기기 감지 로직 추가:";;
            "step_modify_config") echo "4️⃣  설정 파일 수정 (CPU, GPU 등):";;
            "arm64_device_case") echo "# ARM64 기기의 경우:";;
            "armv7_device_case") echo "# ARMv7 기기의 경우:";;

            # 진행 확인
            "continue_with_generic") echo "기본 설정으로 계속 진행하시겠습니까?";;
            "continue_without_config") echo "설정 없이 계속 진행하시겠습니까? (x86_64 기본값 사용, 실패 가능)";;
            "using_generic_config") echo "사용";;
            "user_cancelled") echo "사용자가 중단했습니다. 플랫폼 설정을 추가한 후 다시 실행하세요.";;
            "continuing_with_generic") echo "기기별 최적화 없이 Generic";;
            "config_proceeding") echo "설정으로 진행합니다.";;
            "continuing_without_config") echo "플랫폼 설정 없이 진행합니다. 빌드가 실패할 수 있습니다.";;

            # 일반 메시지
            "latest") echo "최신";;
            "unknown") echo "알 수 없음";;
            "yes") echo "예";;
            "no") echo "아니오";;
            "none") echo "없음";;

            # UI 로그 메시지
            "check_core_utils") echo "필수 유틸리티 누락 여부 확인 중...";;
            "missing_utils") echo "다음 필수 유틸리티가 누락되었습니다";;
            "update_and_install") echo "설치 패키지 목록을 업데이트하고 설치를 진행합니다.";;
            "core_util_install_failed") echo "필수 유틸리티 설치에 실패했습니다. 네트워크 상태를 확인하십시오.";;
            "core_util_install_complete") echo "필수 유틸리티 설치 완료.";;
            "all_core_utils_exist") echo "모든 필수 유틸리티가 시스템에 존재합니다.";;
            "check_retropie_modules") echo "RetroPie 스크립트 모듈 다운로드 확인...";;
            "retropie_modules_updated") echo "RetroPie 스크립트 모듈을 성공적으로 복사/업데이트했습니다.";;
            "dialog_ok_pressed") echo "메뉴에서 [확인] 버튼이 눌렸습니다.";;
            "dialog_cancel_pressed") echo "메뉴에서 [취소] 버튼이 눌렸습니다. 이전 메뉴로 돌아갑니다.";;
            "dialog_esc_pressed") echo "메뉴에서 [ESC] 키가 눌렸습니다. 이전 메뉴로 돌아갑니다.";;
            "dialog_unknown_exit") echo "메뉴에서 알 수 없는 종료 상태가 발생했습니다. 이전 메뉴로 돌아갑니다.";;
            "run_base_install_enter") echo "ui.sh: run_base_system_install 함수 진입.";;
            "run_base_install_module") echo "Base System 설치 모듈(system_install.sh)을 실행합니다.";;
            "base_install_start") echo "🚀 Retro Pangui Base System 설치를 시작합니다...";;
            "base_install_success_log") echo "Base System 설치가 성공적으로 완료되었습니다.";;
            "base_install_error_log") echo "Base System 설치 모듈 실행 중 오류 발생. 상세 로그 파일 확인 필요.";;
            "section_menu_entered") echo "관리 메뉴에 진입했습니다.";;
            "show_package_info_log") echo "정보 보기";;
            "script_not_found") echo "스크립트 파일을 찾을 수 없습니다";;
            "no_package_info") echo "이 패키지에 대한 정보가 없습니다.";;
            "config_tools_entered") echo "설정 / 기타 도구 메뉴에 진입했습니다.";;
            "config_tool_not_implemented") echo "설정/도구 항목 install_es_startup 선택. 로직 미구현.";;
            "share_path_config_start") echo "Share 폴더 경로 설정 시작";;
            "share_path_cancelled") echo "Share 폴더 경로 설정이 사용자에 의해 취소되었습니다.";;
            "share_path_create_cancelled") echo "Share 폴더 경로 생성이 취소되었습니다.";;
            "share_path_creating") echo "새 Share 폴더 생성 및 권한 설정 중.";;
            "share_path_create_failed") echo "Share 폴더 생성 및 권한 설정에 실패했습니다.";;
            "share_path_create_success") echo "Share 폴더 생성 및 권한 설정 완료. 소유자";;
            "share_path_updated") echo "Share 경로가 성공적으로 변경되었습니다.";;
            "samba_config_start") echo "Samba 설정 및 활성화 시작.";;
            "missing_samba_installing") echo "누락된 Samba 패키지 설치 중";;
            "samba_install_failed") echo "Samba 패키지 설치에 실패했습니다.";;
            "samba_install_complete") echo "Samba 패키지 설치 완료.";;
            "samba_already_installed") echo "모든 Samba 패키지가 이미 설치되어 있습니다.";;
            "samba_config_updating") echo "Samba 공유 설정 업데이트 중";;
            "samba_conf_update_failed") echo "smb.conf 파일 업데이트에 실패했습니다.";;
            "samba_conf_update_success") echo "smb.conf 파일 업데이트 완료.";;
            "samba_share_perms_setting") echo "공유 폴더 권한 설정 중.";;
            "samba_share_perms_failed") echo "공유 폴더 권한 설정에 실패했습니다.";;
            "samba_share_perms_success") echo "공유 폴더 권한 설정 완료. 소유자";;
            "samba_service_restarting") echo "Samba 서비스 재시작 및 활성화 중.";;
            "samba_service_failed") echo "Samba 서비스 재시작/활성화에 실패했습니다.";;
            "samba_service_success") echo "Samba 서비스 활성화 및 재시작 완료.";;
            "samba_complete_log") echo "Samba 설정 및 활성화 완료.";;
            "script_update_checking") echo "스크립트 업데이트 확인 중...";;
            "no_remote_version") echo "원격 버전(태그) 정보를 찾을 수 없습니다. 업데이트를 진행할 수 없습니다.";;
            "version_compare_log") echo "버전 비교";;
            "script_update_start") echo "retropangui 스크립트 업데이트 시작.";;
            "stashing_changes") echo "로컬 변경사항을 임시 저장합니다.";;
            "stash_failed") echo "로컬 변경사항 임시 저장 실패.";;
            "fetching_update") echo "원격 저장소에서 업데이트를 가져옵니다.";;
            "update_failed") echo "업데이트 실패 ('git pull --rebase' 실패).";;
            "reapplying_changes") echo "임시 저장된 로컬 변경사항을 다시 적용합니다.";;
            "stash_conflict") echo "로컬 변경사항 적용 중 충돌이 발생했습니다. 로컬 변경사항을 롤백합니다.";;
            "stash_success") echo "로컬 변경사항을 성공적으로 다시 적용했습니다.";;
            "script_update_cancelled") echo "스크립트 업데이트가 사용자에 의해 취소되었습니다.";;
            "script_already_latest") echo "스크립트가 이미 최신 버전입니다.";;
            "uninstall_all_start") echo "전체 설치 제거 시작.";;
            "uninstall_all_complete") echo "전체 설치 제거 완료.";;
            "uninstall_all_cancelled") echo "전체 설치 제거가 사용자에 의해 취소되었습니다.";;
            "reboot_starting") echo "시스템 재부팅을 시작합니다.";;
            "main_ui_entered") echo "ui.sh: Entered main_ui function.";;
            "main_ui_exited") echo "Retro Pangui Configuration Manager 종료.";;

            # Dialog 제목
            "title_base_install") echo "Base System 설치";;
            "title_install_success") echo "✅ 설치 성공";;
            "title_install_failed") echo "❌ 설치 실패";;
            "title_info") echo "정보";;
            "title_package") echo "패키지";;
            "title_warning") echo "경고";;
            "title_error") echo "오류";;
            "title_confirm") echo "확인";;
            "title_package_mgmt") echo "패키지 관리";;
            "title_notification") echo "알림";;
            "title_config_tools") echo "설정 / 기타 도구";;
            "title_share_path_config") echo "Retro Pangui Share 경로 설정";;
            "title_path_not_exist") echo "경로 없음";;
            "title_path_config_complete") echo "경로 설정 완료";;
            "title_samba_complete") echo "Samba 설정 완료";;
            "title_update_check") echo "업데이트 확인";;
            "title_script_update") echo "스크립트 업데이트";;
            "title_update_failed") echo "업데이트 실패";;
            "title_update_complete") echo "업데이트 완료";;
            "title_update_complete_warning") echo "업데이트 완료 (주의)";;
            "title_guide") echo "안내";;
            "title_uninstall_all") echo "전체 설치 제거";;
            "title_uninstall_progress") echo "전체 제거 진행";;
            "title_complete") echo "완료";;
            "title_reboot") echo "시스템 재부팅";;
            "title_reboot_action") echo "재부팅";;

            # Dialog 메시지
            "msg_base_install_confirm") echo "RetroArch/EmulationStation 설치 및 Recalbox 환경 구축/패치를 진행하시겠습니까?\n\n(참고: 설치 진행 상황은 터미널에 직접 출력됩니다.)";;
            "msg_base_install_complete") echo "Base System 설치 및 환경 패치가 완료되었습니다.";;
            "msg_base_install_error") echo "설치 모듈 실행 중 오류가 발생했습니다. 상세한 실패 원인은 로그 파일을 확인하십시오";;
            "msg_no_packages_in_section") echo "이 섹션에는 현재 플랫폼에서 설치 가능한 패키지가 없습니다.";;
            "msg_select_package") echo "패키지를 선택하세요 (설치됨: ✔).";;
            "msg_package_status") echo "상태";;
            "msg_installed") echo "설치됨";;
            "msg_not_installed") echo "미설치";;
            "msg_select_action") echo "수행할 작업을 선택하세요.";;
            "msg_already_installed") echo "이 패키지는 이미 설치되어 있습니다.\n다시 설치(업데이트) 하시겠습니까?";;
            "msg_not_installed_error") echo "이 패키지는 설치되어 있지 않습니다.";;
            "msg_remove_confirm") echo "정말로 '$module_id' 패키지를 제거하시겠습니까?\n이 작업은 되돌릴 수 없습니다.";;
            "msg_script_not_found") echo "스크립트 파일을 찾을 수 없습니다";;
            "msg_section_not_supported") echo "이 섹션의 관리는 아직 지원되지 않습니다.";;
            "msg_tool_not_implemented") echo "세부 설정 로직은 추가 구현이 필요합니다.";;
            "msg_select_tool") echo "실행할 도구를 선택하세요.";;
            "msg_share_path_prompt") echo "Retro Pangui 'share' 폴더의 절대 경로를 입력하세요.\n(현재 경로: $USER_SHARE_PATH)";;
            "msg_path_not_exist") echo "입력하신 경로가 존재하지 않습니다. 새로 생성하시겠습니까?";;
            "msg_path_create_error") echo "Share 폴더 생성 및 권한 설정에 실패했습니다.";;
            "msg_path_set_complete") echo "Retro Pangui Share 경로가 로 설정되었습니다.";;
            "msg_samba_install_error") echo "Samba 패키지 설치에 실패했습니다. 네트워크 상태를 확인하거나 수동으로 설치해주세요.";;
            "msg_samba_conf_error") echo "smb.conf 파일 업데이트에 실패했습니다. 권한을 확인해주세요.";;
            "msg_samba_perms_error") echo "공유 폴더 권한 설정에 실패했습니다.";;
            "msg_samba_service_error") echo "Samba 서비스 재시작/활성화에 실패했습니다.";;
            "msg_samba_complete") echo "Samba 공유가 성공적으로 설정 및 활성화되었습니다.\n공유 경로";;
            "msg_fetching_update") echo "원격 저장소에서 최신 버전 정보를 가져오는 중...";;
            "msg_no_remote_tags") echo "확인 가능한 원격 버전 정보(태그)가 없습니다. 업데이트를 진행할 수 없습니다.";;
            "msg_new_version") echo "새로운 버전의 스크립트를 사용할 수 있습니다.\n\n현재 버전\n최신 버전\n\n업데이트를 진행하시겠습니까?";;
            "msg_stash_failed") echo "로컬 변경사항을 임시 저장하는 데 실패했습니다. 업데이트를 진행할 수 없습니다.";;
            "msg_pull_failed") echo "업데이트를 가져오는 데 실패했습니다. 자세한 내용은 로그를 확인하세요.";;
            "msg_stash_conflict") echo "스크립트가 성공적으로 업데이트되었습니다.\n\n하지만, 로컬 수정사항 중 일부를 자동으로 재적용할 수 없었습니다. 변경하신 내용은 안전하게 백업되어 있으니, 전문가의 도움이 필요할 수 있습니다. (가장 최근 stash 확인)";;
            "msg_update_success_with_stash") echo "스크립트가 성공적으로 업데이트되었으며, 로컬 변경사항도 유지되었습니다.";;
            "msg_update_success") echo "스크립트가 성공적으로 업데이트되었습니다.";;
            "msg_update_component_notice") echo "RetroArch 등 개별 구성요소의 업데이트는 '패키지 관리' 메뉴에서 확인하세요.";;
            "msg_already_latest") echo "현재 최신 버전의 스크립트를 사용하고 있습니다.\n\n현재 버전";;
            "msg_uninstall_confirm") echo "Retro Pangui가 생성한 모든 설정, 빌드 파일, 설치된 코어 및 에뮬레이터를 제거합니다. (Share 폴더 및 로그 제외)\n\n이 작업은 되돌릴 수 없습니다. 정말로 계속하시겠습니까?";;
            "msg_cleanup_progress") echo "생성된 파일 정리 중...";;
            "msg_uninstall_complete") echo "모든 생성 파일(Share 폴더 및 로그 제외) 제거가 완료되었습니다.";;
            "msg_reboot_confirm") echo "시스템을 지금 바로 재부팅하시겠습니까?";;
            "msg_rebooting") echo "시스템을 3초 후 재부팅합니다.";;

            # Menu 항목
            "menu_base_install") echo "Base System 설치";;
            "menu_package_mgmt") echo "패키지 관리 (Base/Main/Driver)";;
            "menu_config_tools") echo "설정 / 기타 도구";;
            "menu_script_update") echo "스크립트 업데이트";;
            "menu_uninstall_all") echo "전부 설치 제거 (Share 폴더 제외)";;
            "menu_reboot") echo "시스템 재부팅";;
            "menu_exit") echo "종료";;
            "menu_install_update") echo "패키지 설치/업데이트";;
            "menu_remove") echo "패키지 제거";;
            "menu_info") echo "패키지 정보 보기";;
            "menu_back") echo "뒤로";;
            "menu_base_packages") echo "base 패키지";;
            "menu_main_packages") echo "메인 패키지";;
            "menu_opt_packages") echo "선택적 패키지";;
            "menu_exp_packages") echo "실험적 패키지";;
            "menu_drivers") echo "드라이버";;
            "menu_config") echo "설정 작업";;
            "menu_depends") echo "의존성";;
            "menu_es_startup") echo "시스템 시작 시 ES 실행";;
            "menu_samba_config") echo "삼바(Samba) 설정 및 활성화";;
            "menu_share_path") echo "Share 폴더 경로 설정 (현재: $USER_SHARE_PATH)";;
            "menu_select_section") echo "관리할 패키지 섹션을 선택하세요.";;
            "menu_prompt") echo "메뉴를 선택하세요.\n(Share 경로 전체: $USER_SHARE_PATH)";;

            # Uninstall 진행 메시지
            "cleanup_temp") echo "임시 파일 제거 중...";;
            "cleanup_es") echo "EmulationStation 설정 제거 중...";;
            "cleanup_ra") echo "RetroArch 설정 제거 중...";;
            "cleanup_cores") echo "설치된 코어 및 에뮬레이터 제거 중...";;
            "cleanup_build") echo "빌드 파일 제거 중...";;
            "cleanup_done") echo "정리 완료.";;

            # Prompts
            "prompt_task_complete") echo "작업이 완료되었습니다. 메뉴로 돌아가려면 [Enter]를 누르세요.";;
            "prompt_remove_complete") echo "제거 작업이 완료되었습니다. 메뉴로 돌아가려면 [Enter]를 누르세요.";;

            # 테스트 스크립트
            "test_title") echo "플랫폼 감지 테스트";;
            "basic_info") echo "기본 정보";;
            "device_detection") echo "기기 감지";;
            "cpu_optimization") echo "CPU 및 최적화 플래그";;
            "optimization_flags") echo "최적화 플래그";;
            "gcc_version") echo "GCC 버전";;
            "platform_flags_info") echo "플랫폼 플래그";;
            "flags_count") echo "플랫폼 플래그 개수";;
            "flags_list") echo "플랫폼 플래그 내용";;
            "config_files") echo "플랫폼별 설정 파일";;
            "config_directory") echo "설정 디렉토리";;
            "loaded_config") echo "로드된 설정 파일";;
            "retroarch_config") echo "RetroArch 설정";;
            "gpu_backends") echo "GPU 백엔드 설정";;
            "build_options") echo "빌드 옵션";;
            "enabled_cores") echo "활성화된 코어 (예시)";;
            "core_count") echo "활성화 코어 개수";;
            "first_cores") echo "처음 5개 코어";;
            "core_list_undefined") echo "활성화 코어 목록: (정의되지 않음)";;
            "configure_options") echo "RetroArch Configure 옵션";;
            "option_count") echo "Configure 옵션 개수";;
            "option_list") echo "옵션 목록";;
            "default_options") echo "Configure 옵션: (기본값 사용)";;
            "test_complete") echo "테스트 완료";;

            *) echo "$key";;  # fallback
        esac
    else
        case "$key" in
            # Platform information
            "platform_info_title") echo "Platform Information";;
            "architecture") echo "Architecture";;
            "detected_device") echo "Detected Device";;
            "cpu_flags") echo "CPU Flags";;
            "platform_flags") echo "Platform Flags";;
            "platform_config_file") echo "Platform Config File";;
            "config_loaded") echo "Config Loaded";;
            "retroarch_version") echo "RetroArch Version";;
            "retroarch_branch") echo "RetroArch Branch";;

            # Warnings and errors
            "warning") echo "⚠️  Warning";;
            "error") echo "❌ Error";;
            "no_platform_config") echo "Platform configuration file not found!";;
            "detected_system_info") echo "📋 Detected System Information:";;
            "device_tree_model") echo "Device-tree Model";;

            # Platform setup guide
            "create_platform_config") echo "📝 You need to create a platform configuration file:";;
            "step_check_configs") echo "1️⃣  Check existing configuration files:";;
            "step_copy_similar") echo "2️⃣  Copy the most similar configuration file:";;
            "step_add_detection") echo "3️⃣  Add device detection logic to detect_device() in config.sh:";;
            "step_modify_config") echo "4️⃣  Modify configuration file (CPU, GPU, etc.):";;
            "arm64_device_case") echo "# For ARM64 devices:";;
            "armv7_device_case") echo "# For ARMv7 devices:";;

            # Confirmation
            "continue_with_generic") echo "Continue with generic configuration?";;
            "continue_without_config") echo "Continue without configuration? (using x86_64 defaults, may fail)";;
            "using_generic_config") echo "using";;
            "user_cancelled") echo "User cancelled. Please add platform configuration and try again.";;
            "continuing_with_generic") echo "Continuing with Generic";;
            "config_proceeding") echo "configuration.";;
            "continuing_without_config") echo "Continuing without platform configuration. Build may fail.";;

            # General messages
            "latest") echo "latest";;
            "unknown") echo "unknown";;
            "yes") echo "yes";;
            "no") echo "no";;
            "none") echo "none";;

            # UI Log messages
            "check_core_utils") echo "Checking for missing essential utilities...";;
            "missing_utils") echo "The following essential utilities are missing";;
            "update_and_install") echo "Updating package lists and proceeding with installation.";;
            "core_util_install_failed") echo "Failed to install essential utilities. Please check your network connection.";;
            "core_util_install_complete") echo "Essential utilities installation complete.";;
            "all_core_utils_exist") echo "All essential utilities are present on the system.";;
            "check_retropie_modules") echo "Checking RetroPie script modules download...";;
            "retropie_modules_updated") echo "Successfully copied/updated RetroPie script modules.";;
            "dialog_ok_pressed") echo "[OK] button was pressed in the menu.";;
            "dialog_cancel_pressed") echo "[Cancel] button was pressed in the menu. Returning to previous menu.";;
            "dialog_esc_pressed") echo "[ESC] key was pressed in the menu. Returning to previous menu.";;
            "dialog_unknown_exit") echo "Unknown exit status occurred in the menu. Returning to previous menu.";;
            "run_base_install_enter") echo "ui.sh: Entered run_base_system_install function.";;
            "run_base_install_module") echo "Executing Base System installation module (system_install.sh).";;
            "base_install_start") echo "🚀 Starting Retro Pangui Base System installation...";;
            "base_install_success_log") echo "Base System installation completed successfully.";;
            "base_install_error_log") echo "Error occurred during Base System installation module execution. Check log file for details.";;
            "section_menu_entered") echo "Entered management menu.";;
            "show_package_info_log") echo "View information";;
            "script_not_found") echo "Script file not found";;
            "no_package_info") echo "No information available for this package.";;
            "config_tools_entered") echo "Entered Settings / Tools menu.";;
            "config_tool_not_implemented") echo "Config/tool item install_es_startup selected. Logic not implemented.";;
            "share_path_config_start") echo "Starting Share folder path configuration";;
            "share_path_cancelled") echo "Share folder path configuration was cancelled by user.";;
            "share_path_create_cancelled") echo "Share folder path creation was cancelled.";;
            "share_path_creating") echo "Creating new Share folder and setting permissions.";;
            "share_path_create_failed") echo "Failed to create Share folder and set permissions.";;
            "share_path_create_success") echo "Share folder creation and permission setting complete. Owner";;
            "share_path_updated") echo "Share path successfully changed.";;
            "samba_config_start") echo "Starting Samba configuration and activation.";;
            "missing_samba_installing") echo "Installing missing Samba packages";;
            "samba_install_failed") echo "Failed to install Samba packages.";;
            "samba_install_complete") echo "Samba package installation complete.";;
            "samba_already_installed") echo "All Samba packages are already installed.";;
            "samba_config_updating") echo "Updating Samba share configuration";;
            "samba_conf_update_failed") echo "Failed to update smb.conf file.";;
            "samba_conf_update_success") echo "smb.conf file update complete.";;
            "samba_share_perms_setting") echo "Setting shared folder permissions.";;
            "samba_share_perms_failed") echo "Failed to set shared folder permissions.";;
            "samba_share_perms_success") echo "Shared folder permission setting complete. Owner";;
            "samba_service_restarting") echo "Restarting and enabling Samba service.";;
            "samba_service_failed") echo "Failed to restart/enable Samba service.";;
            "samba_service_success") echo "Samba service activation and restart complete.";;
            "samba_complete_log") echo "Samba configuration and activation complete.";;
            "script_update_checking") echo "Checking for script updates...";;
            "no_remote_version") echo "Remote version (tag) information not found. Cannot proceed with update.";;
            "version_compare_log") echo "Version comparison";;
            "script_update_start") echo "Starting retropangui script update.";;
            "stashing_changes") echo "Stashing local changes.";;
            "stash_failed") echo "Failed to stash local changes.";;
            "fetching_update") echo "Fetching updates from remote repository.";;
            "update_failed") echo "Update failed ('git pull --rebase' failed).";;
            "reapplying_changes") echo "Reapplying stashed local changes.";;
            "stash_conflict") echo "Conflict occurred while applying local changes. Rolling back local changes.";;
            "stash_success") echo "Successfully reapplied local changes.";;
            "script_update_cancelled") echo "Script update was cancelled by user.";;
            "script_already_latest") echo "Script is already at the latest version.";;
            "uninstall_all_start") echo "Starting complete uninstallation.";;
            "uninstall_all_complete") echo "Complete uninstallation finished.";;
            "uninstall_all_cancelled") echo "Complete uninstallation was cancelled by user.";;
            "reboot_starting") echo "Starting system reboot.";;
            "main_ui_entered") echo "ui.sh: Entered main_ui function.";;
            "main_ui_exited") echo "Retro Pangui Configuration Manager exited.";;

            # Dialog titles
            "title_base_install") echo "Base System Installation";;
            "title_install_success") echo "✅ Installation Success";;
            "title_install_failed") echo "❌ Installation Failed";;
            "title_info") echo "Information";;
            "title_package") echo "Package";;
            "title_warning") echo "Warning";;
            "title_error") echo "Error";;
            "title_confirm") echo "Confirm";;
            "title_package_mgmt") echo "Package Management";;
            "title_notification") echo "Notification";;
            "title_config_tools") echo "Settings / Tools";;
            "title_share_path_config") echo "Retro Pangui Share Path Configuration";;
            "title_path_not_exist") echo "Path Does Not Exist";;
            "title_path_config_complete") echo "Path Configuration Complete";;
            "title_samba_complete") echo "Samba Configuration Complete";;
            "title_update_check") echo "Update Check";;
            "title_script_update") echo "Script Update";;
            "title_update_failed") echo "Update Failed";;
            "title_update_complete") echo "Update Complete";;
            "title_update_complete_warning") echo "Update Complete (Warning)";;
            "title_guide") echo "Guide";;
            "title_uninstall_all") echo "Complete Uninstallation";;
            "title_uninstall_progress") echo "Uninstallation Progress";;
            "title_complete") echo "Complete";;
            "title_reboot") echo "System Reboot";;
            "title_reboot_action") echo "Reboot";;

            # Dialog messages
            "msg_base_install_confirm") echo "Proceed with RetroArch/EmulationStation installation and Recalbox environment setup/patching?\n\n(Note: Installation progress will be displayed directly in the terminal.)";;
            "msg_base_install_complete") echo "Base System installation and environment patching complete.";;
            "msg_base_install_error") echo "An error occurred during installation module execution. Please check the log file for detailed failure reason";;
            "msg_no_packages_in_section") echo "There are no installable packages for the current platform in this section.";;
            "msg_select_package") echo "Select a package (Installed: ✔).";;
            "msg_package_status") echo "Status";;
            "msg_installed") echo "Installed";;
            "msg_not_installed") echo "Not installed";;
            "msg_select_action") echo "Select an action to perform.";;
            "msg_already_installed") echo "This package is already installed.\nDo you want to reinstall (update) it?";;
            "msg_not_installed_error") echo "This package is not installed.";;
            "msg_remove_confirm") echo "Are you sure you want to remove package '$module_id'?\nThis action cannot be undone.";;
            "msg_script_not_found") echo "Script file not found";;
            "msg_section_not_supported") echo "Management of this section is not yet supported.";;
            "msg_tool_not_implemented") echo "Detailed configuration logic requires additional implementation.";;
            "msg_select_tool") echo "Select a tool to run.";;
            "msg_share_path_prompt") echo "Enter the absolute path of the Retro Pangui 'share' folder.\n(Current path: $USER_SHARE_PATH)";;
            "msg_path_not_exist") echo "The path you entered does not exist. Do you want to create it?";;
            "msg_path_create_error") echo "Failed to create Share folder and set permissions.";;
            "msg_path_set_complete") echo "Retro Pangui Share path has been set to";;
            "msg_samba_install_error") echo "Failed to install Samba packages. Please check your network connection or install manually.";;
            "msg_samba_conf_error") echo "Failed to update smb.conf file. Please check permissions.";;
            "msg_samba_perms_error") echo "Failed to set shared folder permissions.";;
            "msg_samba_service_error") echo "Failed to restart/enable Samba service.";;
            "msg_samba_complete") echo "Samba share has been successfully configured and enabled.\nShare path";;
            "msg_fetching_update") echo "Fetching latest version information from remote repository...";;
            "msg_no_remote_tags") echo "No remote version information (tags) available. Cannot proceed with update.";;
            "msg_new_version") echo "A new version of the script is available.\n\nCurrent version\nLatest version\n\nDo you want to proceed with the update?";;
            "msg_stash_failed") echo "Failed to stash local changes. Cannot proceed with update.";;
            "msg_pull_failed") echo "Failed to fetch updates. Please check the logs for details.";;
            "msg_stash_conflict") echo "Script has been successfully updated.\n\nHowever, some of your local modifications could not be automatically reapplied. Your changes are safely backed up, and you may need expert assistance. (Check the most recent stash)";;
            "msg_update_success_with_stash") echo "Script has been successfully updated, and local changes have been preserved.";;
            "msg_update_success") echo "Script has been successfully updated.";;
            "msg_update_component_notice") echo "For updates to individual components like RetroArch, please check the 'Package Management' menu.";;
            "msg_already_latest") echo "You are currently using the latest version of the script.\n\nCurrent version";;
            "msg_uninstall_confirm") echo "This will remove all settings, build files, installed cores and emulators created by Retro Pangui. (Share folder and logs excluded)\n\nThis action cannot be undone. Are you sure you want to continue?";;
            "msg_cleanup_progress") echo "Cleaning up generated files...";;
            "msg_uninstall_complete") echo "All generated files (excluding Share folder and logs) have been removed.";;
            "msg_reboot_confirm") echo "Do you want to reboot the system now?";;
            "msg_rebooting") echo "System will reboot in 3 seconds.";;

            # Menu items
            "menu_base_install") echo "Base System Installation";;
            "menu_package_mgmt") echo "Package Management (Base/Main/Driver)";;
            "menu_config_tools") echo "Settings / Tools";;
            "menu_script_update") echo "Script Update";;
            "menu_uninstall_all") echo "Complete Uninstallation (excluding Share folder)";;
            "menu_reboot") echo "System Reboot";;
            "menu_exit") echo "Exit";;
            "menu_install_update") echo "Install/Update Package";;
            "menu_remove") echo "Remove Package";;
            "menu_info") echo "View Package Information";;
            "menu_back") echo "Back";;
            "menu_base_packages") echo "base packages";;
            "menu_main_packages") echo "main packages";;
            "menu_opt_packages") echo "optional packages";;
            "menu_exp_packages") echo "experimental packages";;
            "menu_drivers") echo "drivers";;
            "menu_config") echo "configuration tasks";;
            "menu_depends") echo "dependencies";;
            "menu_es_startup") echo "Launch ES on System Startup";;
            "menu_samba_config") echo "Configure and Enable Samba";;
            "menu_share_path") echo "Set Share Folder Path (Current: $USER_SHARE_PATH)";;
            "menu_select_section") echo "Select a package section to manage.";;
            "menu_prompt") echo "Select a menu option.\n(Full Share path: $USER_SHARE_PATH)";;

            # Uninstall progress messages
            "cleanup_temp") echo "Removing temporary files...";;
            "cleanup_es") echo "Removing EmulationStation configuration...";;
            "cleanup_ra") echo "Removing RetroArch configuration...";;
            "cleanup_cores") echo "Removing installed cores and emulators...";;
            "cleanup_build") echo "Removing build files...";;
            "cleanup_done") echo "Cleanup complete.";;

            # Prompts
            "prompt_task_complete") echo "Task complete. Press [Enter] to return to menu.";;
            "prompt_remove_complete") echo "Removal complete. Press [Enter] to return to menu.";;

            # Test script
            "test_title") echo "Platform Detection Test";;
            "basic_info") echo "Basic Information";;
            "device_detection") echo "Device Detection";;
            "cpu_optimization") echo "CPU and Optimization Flags";;
            "optimization_flags") echo "Optimization Flags";;
            "gcc_version") echo "GCC Version";;
            "platform_flags_info") echo "Platform Flags";;
            "flags_count") echo "Platform Flags Count";;
            "flags_list") echo "Platform Flags Contents";;
            "config_files") echo "Platform Configuration Files";;
            "config_directory") echo "Config Directory";;
            "loaded_config") echo "Loaded Config File";;
            "retroarch_config") echo "RetroArch Configuration";;
            "gpu_backends") echo "GPU Backend Settings";;
            "build_options") echo "Build Options";;
            "enabled_cores") echo "Enabled Cores (Sample)";;
            "core_count") echo "Enabled Cores Count";;
            "first_cores") echo "First 5 Cores";;
            "core_list_undefined") echo "Enabled cores list: (undefined)";;
            "configure_options") echo "RetroArch Configure Options";;
            "option_count") echo "Configure Options Count";;
            "option_list") echo "Options List";;
            "default_options") echo "Configure Options: (using defaults)";;
            "test_complete") echo "Test Complete";;

            *) echo "$key";;  # fallback
        esac
    fi
}

# 다국어 메시지 출력 (간편 함수)
i18n() {
    msg "$@"
}
