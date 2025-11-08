#!/usr/bin/env bash
#
# 파일명: check.sh
# 설치 상태 확인 함수들
# ===============================================

# RetroArch 설치 여부 확인
# 반환: 0 = 설치됨, 1 = 설치 안됨
is_retroarch_installed() {
    local ra_binary="$RETROARCH_BIN_PATH"
    if [[ -f "$ra_binary" && -x "$ra_binary" ]]; then
        log_msg DEBUG "RetroArch가 이미 설치되어 있습니다: $ra_binary"
        return 0
    else
        log_msg DEBUG "RetroArch가 설치되어 있지 않습니다."
        return 1
    fi
}

# EmulationStation 설치 여부 확인
# 반환: 0 = 설치됨, 1 = 설치 안됨
is_emulationstation_installed() {
    local es_binary="$INSTALL_ROOT_DIR/bin/emulationstation"
    if [[ -f "$es_binary" && -x "$es_binary" ]]; then
        log_msg DEBUG "EmulationStation이 이미 설치되어 있습니다: $es_binary"
        return 0
    else
        log_msg DEBUG "EmulationStation이 설치되어 있지 않습니다."
        return 1
    fi
}

# Libretro 코어 설치 여부 확인
# $1: 모듈 ID (예: lr-pcsx-rearmed)
# 반환: 0 = 설치됨, 1 = 설치 안됨
is_libretro_core_installed() {
    local module_id="$1"

    if [[ -z "$module_id" ]]; then
        log_msg ERROR "is_libretro_core_installed: module_id가 제공되지 않았습니다."
        return 1
    fi

    local core_dir="$LIBRETRO_CORE_PATH/$module_id"
    local metadata_file="$core_dir/.installed_so_name"

    # 메타데이터 파일이 있으면 그걸 사용
    if [[ -f "$metadata_file" ]]; then
        local so_file_name=$(cat "$metadata_file")
        local so_path="$core_dir/$so_file_name"
        if [[ -f "$so_path" ]]; then
            log_msg DEBUG "코어 $module_id가 이미 설치되어 있습니다: $so_path"
            return 0
        fi
    fi

    # 메타데이터가 없으면 폴백: 패턴으로 .so 파일 찾기
    if [[ -d "$core_dir" ]]; then
        local so_files=("$core_dir"/*.so)
        if [[ -f "${so_files[0]}" ]]; then
            log_msg DEBUG "코어 $module_id가 이미 설치되어 있습니다: ${so_files[0]}"
            return 0
        fi
    fi

    log_msg DEBUG "코어 $module_id가 설치되어 있지 않습니다."
    return 1
}

# 패키지 설치 여부 확인 (범용)
# $1: 패키지 이름 (retroarch, emulationstation, 또는 lr-*)
# 반환: 0 = 설치됨, 1 = 설치 안됨
is_package_installed() {
    local package_name="$1"

    case "$package_name" in
        retroarch)
            is_retroarch_installed
            return $?
            ;;
        emulationstation)
            is_emulationstation_installed
            return $?
            ;;
        lr-*)
            is_libretro_core_installed "$package_name"
            return $?
            ;;
        *)
            log_msg WARN "is_package_installed: 알 수 없는 패키지 타입 '$package_name'"
            return 1
            ;;
    esac
}
