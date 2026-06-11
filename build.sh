#!/bin/bash
# build.sh - 호스트에서 실행하는 빌드 진입점
#
# 사용법:
#   ./build.sh [DEVICE]               # 기기 지정 (기본: odroidc5, 버전은 Git 태그 자동 인식)
#   DEVICE=odroidc5 ./build.sh        # 환경변수로 지정
#   VERSION=1.1.0 ./build.sh odroidc5 # 버전 지정
#   ./build.sh --partial              # 부분 빌드: gamepad-mgr + board 파일 + 이미지 재패킹만
#   ./build.sh odroidc5 --partial     # 기기 지정 + 부분 빌드

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --partial 옵션 파싱
PARTIAL=0
ARGS=()
for arg in "$@"; do
    if [ "$arg" = "--partial" ] || [ "$arg" = "-p" ]; then
        PARTIAL=1
    else
        ARGS+=("$arg")
    fi
done
set -- "${ARGS[@]}"

DEVICE="${1:-${DEVICE:-odroidc5}}"
# 사용자가 주입한 VERSION이 없다면 Git 태그를 조회
if [ -z "${VERSION}" ]; then
    # 현재 커밋에 붙은 태그가 있으면 가져오고, 없으면 가장 가까운 태그 기반으로 이름 생성
    # (Git 저장소가 아니거나 태그가 하나도 없으면 에러 방지를 위해 기본값 1.0.0 사용)
    VERSION=$(git describe --tags --always 2>/dev/null || echo "1.0.0")
fi

echo "============================================"
echo "  RETROPANGUI 빌드 시작"
echo "  기기: ${DEVICE}"
echo "  버전: ${VERSION}"
echo "  모드: $([ $PARTIAL -eq 1 ] && echo '부분 빌드 (gamepad-mgr + 이미지)' || echo '전체 빌드')"
echo "  defconfig: retropangui-${DEVICE}_defconfig"
echo "============================================"

# defconfig 존재 확인
DEFCONFIG="${SCRIPT_DIR}/configs/retropangui-${DEVICE}_defconfig"
if [ ! -f "${DEFCONFIG}" ]; then
    echo "ERROR: defconfig 파일이 없습니다: ${DEFCONFIG}"
    ls "${SCRIPT_DIR}/configs/retropangui-"*"_defconfig" 2>/dev/null \
        | sed 's|.*/retropangui-||; s|_defconfig||' \
        | sed 's/^/  - /'
    exit 1
fi

# board 디렉토리 존재 확인
BOARD_DIR="${SCRIPT_DIR}/board/${DEVICE}"
if [ ! -d "${BOARD_DIR}" ]; then
    echo "ERROR: board 디렉토리가 없습니다: ${BOARD_DIR}"
    exit 1
fi

# 볼륨 마운트 디렉터리 사전 생성 (Docker가 root로 자동생성하면 권한 오류)
mkdir -p "${SCRIPT_DIR}/dl"
mkdir -p "${SCRIPT_DIR}/output"

# Docker 접근 권한 확인 — 빌드 시작 전 실패해야 긴 빌드 도중 멈추지 않음
if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker에 접근할 수 없습니다. 다음 명령어로 권한을 추가하세요:"
    echo "  sudo usermod -aG docker \$USER && newgrp docker"
    exit 1
fi

# 전용 바이너리 블롭 확인 (Mali DDK 등)
# (테마는 post-build.sh에서 GitHub에서 자동 다운로드됨)
bash "${SCRIPT_DIR}/scripts/fetch-blobs.sh"

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
# GitHub에 새 커밋을 push해도 재빌드에 반영되지 않음.
# 주의: tarball만 지우면 buildroot가 같은 폴더의 git 캐시에서 fetch 없이
# tarball을 재생성하므로 (낡은 커밋 그대로) git 캐시까지 통째로 삭제해야 함.
# 실제 buildroot 캐시는 buildroot/dl/ 임 (호스트 dl/은 사전 clone 전용).
if [ $PARTIAL -eq 0 ]; then
    echo "[pre] emulationstation 캐시 제거 (최신 main 반영)"
    rm -rf "${SCRIPT_DIR}/dl/emulationstation" \
           "${SCRIPT_DIR}/buildroot/dl/emulationstation" \
           "${SCRIPT_DIR}/buildroot/output/build/emulationstation-main"
fi

_shallow_clone uboot            https://git.odroid.com/yocto/uboot                              odroidc5-v2023.01
_shallow_clone kodi-pangui      https://github.com/xbmc/xbmc                                    21.3-Omega
_shallow_clone retroarch        https://github.com/libretro/RetroArch                           v1.22.2
_shallow_clone emulationstation https://github.com/LeonardWard/retropangui-emulationstation     main

# Docker 이미지 빌드
echo "[1/3] Docker 빌드 환경 이미지 생성 중..."
docker build -t retropangui-builder "${SCRIPT_DIR}"

# Docker 컨테이너에서 빌드 실행
echo "[2/3] Buildroot 빌드 시작..."
docker run --rm \
    --cpus="$(nproc)" \
    --memory="$(awk '/MemTotal/{printf "%dm", $2/1024}' /proc/meminfo)" \
    --memory-swap=-1 \
    -e DEVICE="${DEVICE}" \
    -e VERSION="${VERSION}" \
    -e BUILD_JOBS="$(nproc)" \
    -e PARTIAL="${PARTIAL}" \
    -v "${SCRIPT_DIR}/buildroot:/home/builder/buildroot" \
    -v "${SCRIPT_DIR}/configs:/home/builder/configs" \
    -v "${SCRIPT_DIR}/board:/home/builder/board" \
    -v "${SCRIPT_DIR}/dl:/home/builder/dl" \
    -v "${SCRIPT_DIR}/output:/home/builder/output" \
    -v "${SCRIPT_DIR}/br2-external:/home/builder/br2-external" \
    retropangui-builder \
    bash /home/builder/buildroot/internal_build.sh

echo "[3/3] 빌드 완료!"
echo "============================================"
echo "최종 이미지: ${SCRIPT_DIR}/output/retropangui-${DEVICE}-${VERSION}.img"
echo "============================================"
echo ""
echo "SD 카드에 플래싱하려면:"
echo "  bash scripts/flash-sd.sh output/retropangui-${DEVICE}-${VERSION}.img"


