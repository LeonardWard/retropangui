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
    iniConfig " = " "\"" "$configdir/all/retroarch-core-options.cfg"
    iniGet "$option"
    if [[ -z "$ini_value" ]]; then
        iniSet "$option" "$value"
    fi
    chown "$__user":"$__group" "$configdir/all/retroarch-core-options.cfg"
}

function rp_isInstalled() {
    return 1 # 1 indicates 'not installed'
}