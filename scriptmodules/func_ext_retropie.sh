#!/usr/bin/env bash
# 파일명: retropie_func_ext.sh
# RetroPie/Retro Pangui 설치 환경 확장 함수 모듈

RETROPIE_SETUP_DIR="$MODULES_DIR/retropie_setup"
export scriptdir="$RETROPIE_SETUP_DIR"
export __scriptdir="$RETROPIE_SETUP_DIR"
source "$RETROPIE_SETUP_DIR/retropie_packages.sh"

# 설치 환경 초기화 (필수 패키지 + 변수 + 플랫폼 정보)
setup_env() {
    __ERRMSGS=()
    __INFMSGS=()

    REQUIRED_PKGS=(git build-essential gcc g++ make dialog unzip lsb-release)
    for pkg in "${REQUIRED_PKGS[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            echo "[INFO] $pkg 설치 중..."
            sudo apt-get install -y "$pkg"
        fi
    done

    export __memory_total_kb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
    export __memory_total=$(( __memory_total_kb / 1024 ))
    export __memory_avail_kb=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
    export __memory_avail=$(( __memory_avail_kb / 1024 ))
    export __jobs=$(nproc)
    export __default_makeflags="-j${__jobs}"

    export md_build="/tmp/build"
    export md_inst="/opt/retropangui/libretro/cores"
    mkdir -p "$md_build" "$md_inst"

    export __platform="$(uname -m)"
    export __os_id="$(lsb_release -si 2>/dev/null || echo "Unknown")"
    export __os_codename="$(lsb_release -sc 2>/dev/null || echo "Unknown")"

    export CFLAGS="-O2"
    export MAKEFLAGS="$__default_makeflags"
}

# gitPullOrClone() {
#     # 인자 대신 모두 전역 변수로 처리!
#     local repo="${rp_module_repo}"
#     local dest="${md_build}/${rp_module_id}-libretro"

#     echo "[DEBUG] 함수 진입: repo='$repo' dest='$dest'"

#     local type url branch
#     read -r type url branch <<< "$repo"
#     echo "[DEBUG] PARSE: type='$type' url='$url' branch='$branch'"

#     if [[ "$type" != "git" ]] || [[ -z "$url" ]] || [[ -z "$branch" ]]; then
#         echo "[ERROR] 저장소 URL/브랜치 정보가 올바르지 않습니다: $repo"
#         return 1
#     fi

#     if [ -d "$dest" ]; then
#         echo "[INFO] $dest 존재. git pull"
#         git -C "$dest" pull
#     else
#         echo "[INFO] git clone --branch $branch $url $dest"
#         git clone --branch "$branch" "$url" "$dest"
#     fi
# }

# prepLibretroCoreBuild() {
#     # 반드시 코어 빌드 함수 실행 전에 호출!
#     local coredir="$md_build/${rp_module_id}-libretro"
#     if [ -d "$coredir" ]; then
#         cd "$coredir" || {
#             echo "[ERROR] 코어 빌드 폴더 진입 실패: $coredir"
#             return 1
#         }
#         echo "[INFO] 현재 dir: $(pwd)"
#     else
#         echo "[ERROR] 코어 빌드 폴더 없음: $coredir"
#         return 1
#     fi
# }

# printLibretroBuildDir() {
#     local builddir="$md_build/${rp_module_id}-libretro"
#     local workdir=""

#     # 1) libretro/Makefile, 2) ROOT Makefile 순서로 폴더 안내
#     if [ -f "$builddir/libretro/Makefile" ]; then
#         workdir="$builddir/libretro"
#     elif [ -f "$builddir/Makefile" ]; then
#         workdir="$builddir"
#     else
#         echo "[ERROR] Makefile 위치를 찾을 수 없습니다: $builddir"
#         ls -l "$builddir"
#         return 1
#     fi

#     echo "[INFO] 코어 빌드 디렉토리: $workdir"
#     return 0
# }

installLibretroCore() {
    # .so 우선 복사 방식 유지
    local sofile=""
    if [[ -n "$rp_module_id" ]] && [[ -f "${rp_module_id}_libretro.so" ]]; then
        sofile="${rp_module_id}_libretro.so"
        cp -v "$sofile" "$md_inst/"
        echo "[INFO] 코어 so 파일 설치 완료: $md_inst/$(basename "$sofile")"
    elif [[ -n "$md_ret_require" ]] && [[ -f "$md_ret_require" ]]; then
        cp -v "$md_ret_require" "$md_inst/"
        echo "[INFO] 코어 so 파일 설치 완료: $md_inst/$(basename "$md_ret_require")"
    fi

    # 코어 설치 모듈 내 md_ret_files 배열 전체 복사 지원
    if [[ -n "${md_ret_files[*]}" ]]; then
        for _file in "${md_ret_files[@]}"; do
            if [[ -e "$_file" ]]; then
                if [[ -d "$_file" ]]; then
                    cp -arv "$_file" "$md_inst/"
                    echo "[INFO] 디렉터리 설치: $md_inst/$(basename "$_file")"
                else
                    cp -v "$_file" "$md_inst/"
                    echo "[INFO] 파일 설치: $md_inst/$(basename "$_file")"
                fi
            else
                echo "[WARN] 설치 대상 파일/디렉터리 없음: $_file"
            fi
        done
    fi
}

# 사용 예시:
# source /경로/retropie_func_ext.sh
# setup_env