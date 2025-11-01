#!/usr/bin/env bash
#
# 파일명: ext_retropie_op.sh
# RetroPangui Module: RetroPie 호환 환경 변수 정의 모음
#
# RetroPie-Setup 스크립트와의 호환성을 위해 필요한 
# 2. RetroPie 설치 동작 함수
# ===============================================

function addEmulator() {
    local default="$1"
    local id="$2"
    local system="$3"
    local cmd="$4"

    # check if we are removing the system
    if [[ "$md_mode" == "remove" ]]; then
        delEmulator "$id" "$system"
        return
    fi

    # automatically add parameters for libretro modules
    if [[ "$id" == lr-* && "$cmd" =~ ^"$md_inst"[^[:space:]]*\.so ]]; then
        cmd="$INSTALL_ROOT_DIR/bin/retroarch -L $cmd --config $md_conf_root/$system/retroarch.cfg %ROM%"
    fi

    # create a config folder for the system / port
    mkUserDir "$md_conf_root/$system"

    # add the emulator to the $conf_dir/emulators.cfg if a commandline exists (not used for some ports)
    if [[ -n "$cmd" ]]; then
        iniConfig " = " '"' "$md_conf_root/$system/emulators.cfg"
        iniSet "$id" "$cmd"
        # set a default unless there is one already set
        iniGet "default"
        if [[ -z "$ini_value" && "$default" -eq 1 ]]; then
            iniSet "default" "$id"
        fi
        chown "$__user":"$__group" "$md_conf_root/$system/emulators.cfg"
    fi
}

function addSystem() {
    return 0
}

function defaultRAConfig() {
    local system="$1"
    local dest_config="$md_conf_root/$system/retroarch.cfg"
    local src_config="$INSTALL_ROOT_DIR/etc/retroarch.cfg"

    if [[ -f "$src_config" ]]; then
        log_msg INFO "기본 retroarch.cfg to '$dest_config'"
        sudo mkdir -p "$(dirname "$dest_config")"

        if [[ ! -f "$dest_config" ]]; then
            sudo cp "$src_config" "$dest_config"
            
            # Append system-specific save directories
            log_msg INFO "Appending system-specific save paths for '$system'"
            local system_saves_path="$USER_SAVES_PATH/$system"
            sudo mkdir -p "$system_saves_path"
            
            # Use sudo with tee to append lines as root
            echo "" | sudo tee -a "$dest_config" > /dev/null
            echo "# System-specific save paths (appended by retropangui)" | sudo tee -a "$dest_config" > /dev/null
            echo "savefile_directory = \"$system_saves_path\"" | sudo tee -a "$dest_config" > /dev/null
            echo "savestate_directory = \"$system_saves_path\"" | sudo tee -a "$dest_config" > /dev/null

            sudo chown "$__user":"$__user" "$dest_config"
            sudo chown -R "$__user":"$__user" "$system_saves_path"
        fi
    else
        log_msg WARN "Default retroarch.cfg not found at '$src_config'"
    fi
}

function setRetroArchCoreOption() {
    local option="$1"
    local value="$2"
    sudo mkdir -p "$(dirname "$md_conf_root/all/retroarch-core-options.cfg")"
    iniConfig " = " "\"" "$md_conf_root/all/retroarch-core-options.cfg"
    iniGet "$option"
    if [[ -z "$ini_value" ]]; then
        iniSet "$option" "$value"
    fi
    chown "$__user":"$__group" "$md_conf_root/all/retroarch-core-options.cfg"
}

function rp_isInstalled() {
    return 1 # 1 indicates 'not installed'
}

function applyPatch() {
    local patch_file="$1"
    local patch_applied_file="${patch_file##*/}.applied"

    # 패치 파일의 절대 경로 확인 및 자동 보정
    if [[ ! -f "$patch_file" ]]; then
        # 경로가 유효하지 않으면, md_data를 사용하여 경로 재구성
        if [[ -n "$md_data" && -f "$md_data/${patch_file##*/}" ]]; then
            patch_file="$md_data/${patch_file##*/}"
            log_msg INFO "Patch file path corrected to: $patch_file"
        elif [[ -n "$md_data" ]]; then
            # md_data가 설정되어 있지만 파일이 없는 경우
            log_msg ERROR "Patch file not found in md_data directory: $md_data/${patch_file##*/}"
            return 1
        else
            # md_data도 없고 파일도 찾을 수 없는 경우
            log_msg ERROR "Patch file not found and md_data not set: $patch_file"
            log_msg ERROR "md_data=$md_data, md_id=$md_id"
            return 1
        fi
    fi

    # 빌드 디렉토리에서 패치 적용
    if [[ -n "$md_build" && -d "$md_build" ]]; then
        local build_patch_marker="$md_build/$patch_applied_file"
        if [[ ! -f "$build_patch_marker" ]]; then
            log_msg INFO "Applying patch: $patch_file in $md_build"
            if (cd "$md_build" && patch -p1 < "$patch_file"); then
                touch "$build_patch_marker"
                log_msg INFO "Successfully applied patch: $patch_file"
            else
                log_msg ERROR "Failed to apply patch: $patch_file"
                return 1
            fi
        else
            log_msg INFO "Patch already applied: $patch_file"
        fi
    else
        log_msg ERROR "md_build directory not set or does not exist: $md_build"
        return 1
    fi
    return 0
}