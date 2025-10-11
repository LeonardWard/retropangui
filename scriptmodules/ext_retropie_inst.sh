#!/usr/bin/env bash
#
# 파일명: ext_retropie_inst.sh
# RetroPangui Module: RetroPie 호환 환경 변수 정의 모음
#
# RetroPie-Setup 스크립트와의 호환성을 위해 필요한 
# 3. 설치 및 빌드 관련 함수
# ===============================================

function gitPullOrClone() {
    log_msg INFO "gitPullOrClone wrapper executed..."

    local repo_info="$rp_module_repo"
    local dest_dir="${md_build}/${rp_module_id}"

    local type url branch
    read -r type url branch <<< "$repo_info"

    if [[ "$type" != "git" ]] || [[ -z "$url" ]]; then
        log_msg ERROR "Invalid repository URL: $repo_info"
        return 1
    fi
    
    if [[ -n "$branch" ]]; then
        git_Pull_Or_Clone "$url" "$dest_dir" --branch "$branch" --depth=1
    else
        git_Pull_Or_Clone "$url" "$dest_dir" --depth=1
    fi
}

function installLibretroCore() {
    local build_dir="$1"
    local module_id="$2" # 새로 추가된 인자: 코어 ID

    if [[ -z "$build_dir" || ! -d "$build_dir" ]]; then
        log_msg ERROR "installLibretroCore: Invalid build directory provided."
        return 1
    fi
    if [[ -z "$module_id" ]]; then
        log_msg ERROR "installLibretroCore: Module ID not provided."
        return 1
    fi

    log_msg INFO "Installing files for $module_id from $build_dir..."

    if [[ -n "${md_ret_files[*]}" ]]; then
        for _file in "${md_ret_files[@]}"; do
            local src_path="$build_dir/$_file"
            local dest_dir=""
            local file_extension="${_file##*.}" # 파일 확장자 추출
            local file_basename="${_file##*/}" # 파일 이름 추출

            if [[ ! -e "$src_path" ]]; then
                log_msg WARN "File/directory to install not found: $src_path"
                continue
            fi

            # 파일 종류에 따라 목적지 결정
            case "$file_extension" in
                so) # Libretro 코어 파일
                    dest_dir="$md_inst"
                    ;;
                md|txt|chm|html|df) # 문서 파일
                    dest_dir="$INSTALL_ROOT_DIR/docs/$module_id"
                    ;;
                *) # 그 외 파일 (폴더 포함)
                    if [[ -d "$src_path" ]]; then
                        if [[ "$_file" == "docs" ]]; then # Explicitly handle 'docs' directory
                            dest_dir="$INSTALL_ROOT_DIR/docs/$module_id"
                        else
                            # 'metadata', 'dats', 'Databases', 'Machines' 같은 폴더
                            dest_dir="$md_inst"
                        fi
                    else
                        # Check for common documentation files without extension
                        case "$file_basename" in
                            AUTHORS|COPYING|NEWS|LICENSE)
                                dest_dir="$INSTALL_ROOT_DIR/docs/$module_id"
                                ;;
                            *)
                                # 기본값: 코어 설치 폴더
                                dest_dir="$md_inst"
                                ;;
                        esac
                    fi
                    ;;
            esac

            # 목적지 디렉터리 생성 (mkUserDir 함수 사용)
            mkUserDir "$dest_dir"

            log_msg INFO "Copying $src_path to $dest_dir"
            cp -Rvf "$src_path" "$dest_dir"
        done
        log_msg SUCCESS "All files for $module_id installed to their respective locations."
    else
        log_msg INFO "No files listed in md_ret_files for $module_id. Nothing to install."
    fi
}

## @fn rpSwap()
## @param command *on* to add swap if needed and *off* to remove later
## @param memory total memory needed (swap added = memory needed - available memory)
## @brief Adds additional swap to the system if needed.
function rpSwap() {
    local command=$1
    local swapfile="$__swapdir/swap"
    case $command in
        on)
            rpSwap off
            local needed=$2
            local size=$((needed - __memory_avail))
            mkdir -p "$__swapdir/"
            if [[ $size -ge 0 ]]; then
                echo "Adding $size MB of additional swap"
                fallocate -l ${size}M "$swapfile"
                chmod 600 "$swapfile"
                mkswap "$swapfile"
                swapon "$swapfile"
            fi
            ;;
        off)
            echo "Removing additional swap"
            swapoff "$swapfile" 2>/dev/null
            rm -f "$swapfile"
            ;;
    esac
}