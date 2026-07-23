#!/bin/bash
# build.sh - 호스트에서 실행하는 빌드 진입점
#
# 사용법:
#   ./build.sh [DEVICE]               # img + OTA squashfs 둘 다 생성 (기본)
#   ./build.sh --img                  # img만 생성 (전체 빌드)
#   ./build.sh --ota                  # OTA squashfs만 생성 (빠른 빌드: ES만 재빌드)
#   ./build.sh --partial              # 부분 빌드: gamepad-mgr + board 파일 + 이미지 재패킹만
#   DEVICE=odroidc5 ./build.sh        # 환경변수로 기기 지정
#   VERSION=1.1.0 ./build.sh odroidc5 # 버전 지정

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 옵션 파싱
PARTIAL=0
BUILD_IMG=0
BUILD_OTA=0
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --partial|-p) PARTIAL=1 ;;
        --img|-i)     BUILD_IMG=1 ;;
        --ota|-o)     BUILD_OTA=1 ;;
        *)            ARGS+=("$arg") ;;
    esac
done
set -- "${ARGS[@]}"

# 플래그 미지정 시 기본값: 둘 다
if [ $BUILD_IMG -eq 0 ] && [ $BUILD_OTA -eq 0 ]; then
    BUILD_IMG=1
    BUILD_OTA=1
fi

DEVICE="${1:-${DEVICE:-odroidc5}}"
if [ -z "${VERSION}" ]; then
    VERSION=$(git describe --tags --long --always 2>/dev/null || echo "1.0.0")
fi

DEFCONFIG="${SCRIPT_DIR}/configs/retropangui-${DEVICE}_defconfig"
BOARD_DIR="${SCRIPT_DIR}/board/${DEVICE}"

if [ $BUILD_IMG -eq 1 ] && [ $BUILD_OTA -eq 1 ]; then
    _MODE="전체빌드 (img + squashfs)"
elif [ $BUILD_IMG -eq 1 ]; then
    _MODE="전체빌드 (img만)"
elif [ $BUILD_OTA -eq 1 ]; then
    _MODE="OTA 빠른빌드 (squashfs만)"
fi
[ $PARTIAL -eq 1 ] && _MODE="부분빌드"

echo "============================================"
echo "  RETROPANGUI 빌드 시작"
echo "  기기: ${DEVICE}"
echo "  버전: ${VERSION}"
echo "  모드: ${_MODE}"
echo "  defconfig: retropangui-${DEVICE}_defconfig"
echo "============================================"

# ─── 환경 감지 ───────────────────────────────────────────────────
_IS_WSL2=0
grep -qi "microsoft" /proc/version 2>/dev/null && _IS_WSL2=1 || true

_DISTRO=""
_PKG_MGR="unknown"
if [ -f /etc/os-release ]; then
    _DISTRO=$(. /etc/os-release && echo "${ID:-}")
fi
case "${_DISTRO}" in
    ubuntu|debian|linuxmint|pop)     _PKG_MGR="apt" ;;
    fedora|rhel|centos|rocky|almalinux) _PKG_MGR="dnf" ;;
    arch|manjaro|endeavouros)        _PKG_MGR="pacman" ;;
    opensuse*|sles)                  _PKG_MGR="zypper" ;;
    *)  command -v brew &>/dev/null  && _PKG_MGR="brew" || true ;;
esac

# ─── 사전 조건 확인 ──────────────────────────────────────────────
_PREFLIGHT_OK=1
_pf_err()  { echo "  [ERROR] $*"; _PREFLIGHT_OK=0; }
_pf_warn() { echo "  [WARN]  $*"; }

echo ">>> 사전 조건 확인 중..."
[ "$_IS_WSL2" -eq 1 ] && echo "  환경: WSL2 (${_DISTRO})" || echo "  환경: ${_DISTRO:-unknown} / pkg: ${_PKG_MGR}"

# 필수 CLI 도구
_tool_hint() {
    local tool="$1"
    case "${_PKG_MGR}" in
        apt)
            case "$tool" in
                docker) echo "       설치: sudo apt install -y docker.io && sudo systemctl enable --now docker" ;;
                git)    echo "       설치: sudo apt install -y git" ;;
                awk)    echo "       설치: sudo apt install -y gawk" ;;
                nproc)  echo "       설치: sudo apt install -y coreutils" ;;
                unzip)  echo "       설치: sudo apt install -y unzip" ;;
            esac ;;
        dnf)
            case "$tool" in
                docker) echo "       설치: sudo dnf install -y docker && sudo systemctl enable --now docker" ;;
                git)    echo "       설치: sudo dnf install -y git" ;;
                awk)    echo "       설치: sudo dnf install -y gawk" ;;
                nproc)  echo "       설치: sudo dnf install -y coreutils" ;;
                unzip)  echo "       설치: sudo dnf install -y unzip" ;;
            esac ;;
        pacman)
            case "$tool" in
                docker) echo "       설치: sudo pacman -S docker && sudo systemctl enable --now docker" ;;
                git)    echo "       설치: sudo pacman -S git" ;;
                awk)    echo "       설치: sudo pacman -S gawk" ;;
                nproc)  echo "       설치: sudo pacman -S coreutils" ;;
                unzip)  echo "       설치: sudo pacman -S unzip" ;;
            esac ;;
        brew)
            case "$tool" in
                docker) echo "       설치: brew install --cask docker" ;;
                git)    echo "       설치: brew install git" ;;
                awk)    echo "       설치: brew install gawk" ;;
                nproc)  echo "       설치: brew install coreutils" ;;
                unzip)  echo "       설치: brew install unzip" ;;
            esac ;;
        *)
            case "$tool" in
                docker) echo "       설치: https://docs.docker.com/engine/install/" ;;
                *)      echo "       패키지 매니저를 감지하지 못했습니다. $tool 을 수동 설치하세요." ;;
            esac ;;
    esac
}
# unzip: fetch-fonts.sh가 호스트에서(Docker 진입 전) 직접 압축을 풀 때 씀 -
# 없으면 사전 조건 확인은 통과하고 한참 지나서야 실패하는 문제가 있었음
# (2026-07-18, 다른 호스트에서 실측).
for _tool in git awk nproc docker unzip; do
    if ! command -v "$_tool" &>/dev/null; then
        _pf_err "$_tool 가 설치되어 있지 않습니다."
        _tool_hint "$_tool"
    fi
done

# defconfig
if [ ! -f "${DEFCONFIG}" ]; then
    _pf_err "defconfig 없음: ${DEFCONFIG}"
    echo "       사용 가능한 기기:"
    ls "${SCRIPT_DIR}/configs/retropangui-"*"_defconfig" 2>/dev/null \
        | sed 's|.*/retropangui-||; s|_defconfig||; s/^/         - /'
fi

# board 디렉토리
[ -d "${BOARD_DIR}" ] || _pf_err "board 디렉토리 없음: ${BOARD_DIR}"

# Dockerfile
[ -f "${SCRIPT_DIR}/Dockerfile" ] || _pf_err "Dockerfile 없음: ${SCRIPT_DIR}/Dockerfile"

# fetch-blobs.sh
[ -f "${SCRIPT_DIR}/board/odroidc5/fetch-blobs.sh" ] || _pf_err "board/odroidc5/fetch-blobs.sh 없음"
[ -f "${SCRIPT_DIR}/board/odroidc5/fetch-fonts.sh" ] || _pf_err "board/odroidc5/fetch-fonts.sh 없음"

# 코어 등록 일관성 1단 검사(빠른 사전 경고) - defconfig↔systems.json↔패키지 디렉토리
# 3자 대조. 여기서는 패키지 존재 여부만으로 판정 가능해 몇 초 안에 끝남 - 실제
# 설치된 .so 기준의 권위 있는 검사는 post-build.sh(2단)가 빌드 중에 수행하고
# 그쪽이 불일치 시 빌드를 중단시킨다(todo-20260716-core-registration-check.html).
if [ -f "${SCRIPT_DIR}/scripts/check-core-registration.sh" ]; then
    echo "  - 코어 등록 일관성 사전 점검 중..."
    bash "${SCRIPT_DIR}/scripts/check-core-registration.sh" "${SCRIPT_DIR}" || \
        _pf_warn "코어 등록 불일치 발견 (위 [ERROR] 참고) - post-build.sh에서 다시 검사되며 실물 기준 불일치면 빌드가 중단됩니다"
fi

# buildroot (gitignore 제외 대상 — Docker 내부에서 자동 다운로드됨)
[ -f "${SCRIPT_DIR}/buildroot/Makefile" ] || \
    echo "  [INFO]  buildroot 소스 없음 — 첫 빌드 시 Docker 내부에서 자동 다운로드됩니다."

# Docker 접근 (미설치 / daemon 미실행 / 권한 없음 구분)
if command -v docker &>/dev/null; then
    _DOCKER_ERR=$(docker info 2>&1) || {
        if echo "$_DOCKER_ERR" | grep -qi "permission denied"; then
            _pf_err "Docker 소켓 권한 없음"
            echo "       해결: sudo usermod -aG docker \$USER"
            echo "             그 후 터미널을 닫고 다시 열거나: newgrp docker"
        elif echo "$_DOCKER_ERR" | grep -qi "cannot connect\|connection refused\|No such file\|Is the docker daemon running"; then
            _pf_err "Docker 데몬이 실행되지 않았습니다"
            if [ "$_IS_WSL2" -eq 1 ]; then
                echo "       해결: sudo service docker start"
            else
                echo "       해결: sudo systemctl start docker"
            fi
        else
            _pf_err "Docker 오류: $(echo "$_DOCKER_ERR" | grep -i 'error\|cannot\|failed' | head -1 || echo '알 수 없는 오류')"
        fi
    }
fi

# 디스크 여유 공간 (경고만)
_check_space() {
    local dir="$1" min_gb="$2" label="$3"
    mkdir -p "$dir" 2>/dev/null
    local avail_gb
    avail_gb=$(df -k "$dir" 2>/dev/null | awk 'NR==2{printf "%d", $4/1024/1024}')
    if [ -z "$avail_gb" ]; then return 0; fi
    if [ "$avail_gb" -lt "$min_gb" ]; then
        _pf_warn "${label} 여유 공간 ${avail_gb}GB (권장 ${min_gb}GB 이상)"
    fi
}
_check_space "${SCRIPT_DIR}/output"    10  "output"
_check_space "${SCRIPT_DIR}/buildroot" 40  "buildroot"

# RAM (경고만)
_ram_gb=$(awk '/MemTotal/{printf "%d", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo 0)
if [ "$_ram_gb" -lt 4 ]; then
    _pf_warn "RAM ${_ram_gb}GB — 빌드에 최소 4GB 권장"
fi

if [ "$_PREFLIGHT_OK" -eq 0 ]; then
    echo ""
    echo ">>> 사전 조건 미충족으로 빌드를 중단합니다."
    exit 1
fi
echo "  OK"

# changelog.txt를 현재 태그 어노테이션에서 자동 생성
_CHANGELOG_DEST="${SCRIPT_DIR}/board/${DEVICE}/rootfs-overlay/usr/share/retropangui/changelog.txt"
_BASE_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
if [ -n "$_BASE_TAG" ]; then
    _TAG_BODY=$(git for-each-ref "refs/tags/${_BASE_TAG}" --format='%(contents)' 2>/dev/null)
    if [ -n "$_TAG_BODY" ]; then
        printf '%s\n' "$_TAG_BODY" > "$_CHANGELOG_DEST"
        echo ">>> changelog.txt: ${_BASE_TAG} 태그 어노테이션으로 생성"
    else
        echo ">>> changelog.txt: ${_BASE_TAG} 는 경량 태그 — 기존 파일 유지"
    fi
else
    echo ">>> changelog.txt: git 태그 없음 — 기존 파일 유지"
fi

# 볼륨 마운트 디렉터리 사전 생성 (Docker가 root로 자동생성하면 권한 오류)
mkdir -p "${SCRIPT_DIR}/dl" "${SCRIPT_DIR}/output"

# 전용 바이너리 블롭 확인 (Mali DDK 등)
# (테마는 post-build.sh에서 GitHub에서 자동 다운로드됨)
bash "${SCRIPT_DIR}/board/odroidc5/fetch-blobs.sh"
bash "${SCRIPT_DIR}/board/odroidc5/fetch-fonts.sh"

# 대형 git 패키지 사전 shallow clone
# - Buildroot의 git 다운로더는 기본적으로 --depth=1을 사용하도록 패치됨
#   (buildroot/support/download/git + BR2_GIT_FETCH_DEPTH=1)
# - 하지만 첫 빌드 시 Docker 안에서 clone이 시작되면 OOM이 발생할 수 있으므로
#   여기서 미리 dl/ 캐시에 받아두면 Docker 안에서는 fetch(업데이트)만 수행
# - 이미 캐시가 있으면 스킵 (증분 빌드 시 중요)
_shallow_clone() {
    local name="$1" url="$2" branch="$3"
    local dldir="${SCRIPT_DIR}/dl/${name}/git"
    if [ ! -d "${dldir}/.git" ]; then
        echo "[pre] ${name} shallow clone 중 (${branch})..."
        git clone --depth=1 -b "${branch}" "${url}" "${dldir}"
    else
        echo "[pre] ${name} 캐시 존재 (스킵)"
    fi
}

# 서브모듈 포함 대형 패키지는 반드시 여기서 미리 clone
# (git SITE_METHOD이고 서브모듈 있는 것들)
# emulationstation은 버전이 브랜치(main)라서 dl 캐시가 한 번 생기면
# GitHub에 새 커밋을 push해도 재빌드에 반영되지 않음 - 예전엔 이걸 매번
# 무조건 통째로 삭제해서 매 전체빌드마다 ES를 처음부터 다시 컴파일했음
# (todo-20260720-build-force-clean-audit.html B분류).
#
# 2026-07-20 조건부화: ES는 이 프로젝트와 별개 저장소(포크)라 오늘 도입한
# git-diff 기반 통합 감지 스크립트(이 프로젝트 자체 커밋만 비교)로는 변경
# 여부를 알 수 없음. 대신 "로컬 편집 클론(../retropangui-emulationstation)의
# 현재 커밋"을 기준으로 삼음 - ES 수정은 항상 이 클론에서 커밋 후 push하는
# 방식이라(이 세션 내내 지켜온 방식), 로컬 HEAD가 곧 GitHub main의 최신
# 상태와 같음. 그래서 매번 fetch로 원격에 물어볼 필요 없이 로컬 파일 하나만
# 비교하면 됨.
ES_LOCAL_REPO="${SCRIPT_DIR}/../retropangui-emulationstation"
ES_LAST_BUILT_FILE="${SCRIPT_DIR}/buildroot/output/.last_built_es_commit"
ES_SKIP_REFETCH=0
if [ $PARTIAL -eq 0 ]; then
    ES_LOCAL_COMMIT=""
    if [ -d "${ES_LOCAL_REPO}/.git" ]; then
        ES_LOCAL_COMMIT="$(git -C "${ES_LOCAL_REPO}" rev-parse HEAD 2>/dev/null || true)"
    fi
    ES_PREV_COMMIT=""
    [ -f "${ES_LAST_BUILT_FILE}" ] && ES_PREV_COMMIT="$(cat "${ES_LAST_BUILT_FILE}")"

    if [ -n "${ES_LOCAL_COMMIT}" ] && [ "${ES_LOCAL_COMMIT}" = "${ES_PREV_COMMIT}" ] \
        && [ -d "${SCRIPT_DIR}/dl/emulationstation" ] \
        && [ -d "${SCRIPT_DIR}/buildroot/output/build/emulationstation-main" ]; then
        echo "[pre] emulationstation 변경 없음(${ES_LOCAL_COMMIT:0:7}) - 캐시 유지, 재빌드 스킵"
        ES_SKIP_REFETCH=1
    else
        echo "[pre] emulationstation 캐시 제거 (최신 main 반영)"
        rm -rf "${SCRIPT_DIR}/dl/emulationstation" \
               "${SCRIPT_DIR}/buildroot/dl/emulationstation" \
               "${SCRIPT_DIR}/buildroot/output/build/emulationstation-main"
        # target에 설치된 바이너리도 삭제해야 재설치됨 (build만 지우면 target은 그대로)
        rm -f  "${SCRIPT_DIR}/buildroot/output/target/usr/bin/emulationstation"
    fi
fi

_shallow_clone uboot             https://git.odroid.com/yocto/uboot                             odroidc5-v2023.01
_shallow_clone kodi-pangui       https://github.com/xbmc/xbmc                                   21.3-Omega
_shallow_clone retroarch         https://github.com/libretro/RetroArch                          v1.22.2
_shallow_clone retroarch-assets  https://github.com/libretro/retroarch-assets.git              master
_shallow_clone emulationstation  https://github.com/LeonardWard/retropangui-emulationstation    main

# 2026-07-20: git 커밋 비교로 실제 변경된 패키지만 캐시 정리
# (todo-20260720-build-force-clean-audit.html) - --partial은 targeted
# 재빌드라 별개 로직이므로 대상에서 제외.
if [ $PARTIAL -eq 0 ]; then
    bash "${SCRIPT_DIR}/scripts/detect-stale-package-caches.sh" "${DEVICE}"
fi

# Docker 이미지 빌드
echo "[1/3] Docker 빌드 환경 이미지 생성 중..."
docker build -t retropangui-builder "${SCRIPT_DIR}"

# Docker 컨테이너에서 빌드 실행
echo "[2/3] Buildroot 빌드 시작..."
# RetroPangui: wpewebkit(WebKit) 도입 후(2026-07-23) --memory-swap=-1(무제한
# 스왑) + BUILD_JOBS=nproc 고정 조합이 호스트 전체를 OOM으로 몰아넣는 걸
# 실측(빌드 컨테이너뿐 아니라 무관한 tmux 세션까지 같이 죽음 - 커널
# OOM killer가 컨테이너 cgroup에 국한되지 않고 전역에서 희생양을 고른 것으로
# 추정). 스왑을 물리메모리+4GB로 캡 걸고, BUILD_JOBS는 환경변수로 낮출 수
# 있게 열어둠(예: BUILD_JOBS=4 ./build.sh - 메모리 무거운 패키지 빌드 시).
_MEM_MB="$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo)"
docker run --rm \
    --cpus="$(nproc)" \
    --memory="${_MEM_MB}m" \
    --memory-swap="$((_MEM_MB + 4096))m" \
    -e DEVICE="${DEVICE}" \
    -e VERSION="${VERSION}" \
    -e BUILD_JOBS="${BUILD_JOBS:-$(nproc)}" \
    -e PARTIAL="${PARTIAL}" \
    -e BUILD_IMG="${BUILD_IMG}" \
    -e BUILD_OTA="${BUILD_OTA}" \
    -e ES_SKIP_REFETCH="${ES_SKIP_REFETCH}" \
    -v "${SCRIPT_DIR}/buildroot:/home/builder/buildroot" \
    -v "${SCRIPT_DIR}/configs:/home/builder/configs" \
    -v "${SCRIPT_DIR}/board:/home/builder/board" \
    -v "${SCRIPT_DIR}/dl:/home/builder/dl" \
    -v "${SCRIPT_DIR}/output:/home/builder/output" \
    -v "${SCRIPT_DIR}/br2-external:/home/builder/br2-external" \
    -v "${SCRIPT_DIR}/docker:/home/builder/docker" \
    retropangui-builder \
    bash /home/builder/docker/internal_build.sh

# 빌드 성공 시점의 소스 상태를 기록 - 다음 빌드의 stale-cache 감지 기준점.
# HEAD 커밋이 아니라 stash 임시 커밋을 기록하는 이유: 커밋 안 한 수정을 둔 채
# 빌드한 뒤 그 수정을 되돌리면, HEAD 기준 diff로는 "변경 없음"이라 수정본으로
# 만들어진 캐시가 감지 안 되는 구멍이 있음. stash create는 워킹트리 상태
# 그대로를 임시 커밋으로 만들어줌(변경 없으면 빈 문자열 -> HEAD 사용).
# gc가 dangling 커밋을 지워버리지 않도록 ref로도 고정해둔다.
if [ $PARTIAL -eq 0 ]; then
    BUILT_STATE="$(git -C "${SCRIPT_DIR}" stash create 2>/dev/null || true)"
    [ -z "${BUILT_STATE}" ] && BUILT_STATE="$(git -C "${SCRIPT_DIR}" rev-parse HEAD)"
    git -C "${SCRIPT_DIR}" update-ref refs/retropangui/last-built "${BUILT_STATE}"
    echo "${BUILT_STATE}" > "${SCRIPT_DIR}/buildroot/output/.last_built_commit"

    # emulationstation 조건부 재빌드(위 [pre] 단계)의 다음번 기준점 기록
    [ -n "${ES_LOCAL_COMMIT:-}" ] && echo "${ES_LOCAL_COMMIT}" > "${ES_LAST_BUILT_FILE}"
fi

echo "[3/3] 빌드 완료!"
echo "============================================"
if [ $BUILD_IMG -eq 1 ]; then
    echo "최종 이미지: ${SCRIPT_DIR}/output/retropangui-${DEVICE}-${VERSION}.img"
    echo "  플래싱:  bash scripts/flash-sd.sh output/retropangui-${DEVICE}-${VERSION}.img"
fi
if [ $BUILD_OTA -eq 1 ]; then
    echo "OTA squashfs: ${SCRIPT_DIR}/output/retropangui-${DEVICE}-${VERSION}.squashfs"
    echo "SHA256:       ${SCRIPT_DIR}/output/retropangui-${DEVICE}-${VERSION}.squashfs.sha256"
    echo "  배포:    scripts/ota.sh push output/retropangui-${DEVICE}-${VERSION}.squashfs --serv"
fi
echo "============================================"
