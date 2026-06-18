#!/bin/bash
# internal_build.sh - Docker 컨테이너 내부에서 실행되는 빌드 스크립트

set -eo pipefail

BUILDROOT_VERSION="${BUILDROOT_VERSION:-2024.02.1}"
DEVICE="${DEVICE:-odroidc5}"
VERSION="${VERSION:-1.0.0}"
PARTIAL="${PARTIAL:-0}"
OTA="${OTA:-0}"
DEFCONFIG="retropangui-${DEVICE}_defconfig"

cd /home/builder/buildroot

# git 다운로드를 shallow(--depth=1)로 강제 → 히스토리 불필요한 빌드 패키지 다운로드 시간 단축
# full history가 필요한 패키지가 생기면 해당 .mk에서 BR2_GIT_FETCH_DEPTH="" 오버라이드
export BR2_GIT_FETCH_DEPTH=1

echo "============================================"
echo "  Buildroot 내부 빌드 스크립트"
echo "  Buildroot 버전: ${BUILDROOT_VERSION}"
echo "  기기: ${DEVICE}"
echo "  프로젝트 버전: ${VERSION}"
echo "  모드: $([ "$OTA" = "1" ] && echo OTA빌드 || { [ "$PARTIAL" = "1" ] && echo 부분빌드 || echo 전체빌드; })"
echo "  defconfig: ${DEFCONFIG}"
echo "============================================"

# OTA 빌드: emulationstation 재빌드 + squashfs만 생성 (img 없음)
if [ "$OTA" = "1" ]; then
    BR2_EXTERNAL_PATH=/home/builder/br2-external
    echo "[OTA 빌드] board 파일 복사 중..."
    mkdir -p board/${DEVICE}
    rsync -a --delete /home/builder/board/${DEVICE}/ board/${DEVICE}/
    mkdir -p board/${DEVICE}/rootfs-overlay/etc
    echo "${VERSION}" > board/${DEVICE}/rootfs-overlay/etc/retropangui-version

    echo "[OTA 빌드] emulationstation 소스 최신화 중..."
    if [ -d "output/build/emulationstation-main/.git" ]; then
        git -C output/build/emulationstation-main fetch --depth=1 origin main 2>&1 || true
        git -C output/build/emulationstation-main reset --hard origin/main 2>&1 || true
    fi

    echo "[OTA 빌드] emulationstation 재빌드 중..."
    rm -f output/build/emulationstation-main/.stamp_built           output/build/emulationstation-main/.stamp_target_installed
    JOBS="${BUILD_JOBS:-$(nproc)}"
    make BR2_EXTERNAL="${BR2_EXTERNAL_PATH}" -j${JOBS} emulationstation 2>&1 | tee /home/builder/output/build-ota.log

    echo "[OTA 빌드] squashfs 재생성 중..."
    make BR2_EXTERNAL="${BR2_EXTERNAL_PATH}" rootfs-squashfs 2>&1 | tee -a /home/builder/output/build-ota.log

    OUTPUT_SQ="retropangui-${DEVICE}-${VERSION}.squashfs"
    if [ -f output/images/rootfs.squashfs ]; then
        cp output/images/rootfs.squashfs /home/builder/output/${OUTPUT_SQ}
        sha256sum /home/builder/output/${OUTPUT_SQ} | awk '{print $1}'             > /home/builder/output/${OUTPUT_SQ}.sha256
        echo "============================================"
        echo "  OTA 빌드 성공!"
        echo "  squashfs: ${OUTPUT_SQ}"
        echo "  크기:     $(du -h /home/builder/output/${OUTPUT_SQ} | cut -f1)"
        echo "  SHA256:   $(cat /home/builder/output/${OUTPUT_SQ}.sha256)"
        echo "============================================"
    else
        echo "ERROR: rootfs.squashfs 생성 실패!"
        exit 1
    fi
    exit 0
fi

# 부분 빌드: board 파일 복사 + gamepad-mgr 재빌드 + 이미지 재패킹만 수행
if [ "$PARTIAL" = "1" ]; then
    BR2_EXTERNAL_PATH=/home/builder/br2-external
    echo "[부분 빌드] board 파일 복사 중..."
    mkdir -p board/${DEVICE}
    rsync -a --delete /home/builder/board/${DEVICE}/ board/${DEVICE}/
    mkdir -p board/${DEVICE}/rootfs-overlay/etc
    echo "${VERSION}" > board/${DEVICE}/rootfs-overlay/etc/retropangui-version

    echo "[부분 빌드] gamepad-mgr 재빌드 중..."
    rm -rf output/build/gamepad-mgr-*/
    JOBS="${BUILD_JOBS:-$(nproc)}"
    make BR2_EXTERNAL="${BR2_EXTERNAL_PATH}" -j${JOBS} 2>&1 | tee /home/builder/output/build-partial.log

    OUTPUT_IMG="retropangui-${DEVICE}-${VERSION}.img"
    if [ -f output/images/sdcard.img ]; then
        cp output/images/sdcard.img /home/builder/output/${OUTPUT_IMG}
        echo "============================================"
        echo "  부분 빌드 성공!"
        echo "  이미지: ${OUTPUT_IMG}"
        echo "  크기: $(du -h /home/builder/output/${OUTPUT_IMG} | cut -f1)"
        echo "============================================"
    else
        echo "ERROR: sdcard.img 생성 실패!"
        exit 1
    fi
    exit 0
fi

# Buildroot 소스 다운로드 (없을 경우)
if [ ! -f Makefile ]; then
    echo "[1/6] Buildroot 소스 다운로드 중..."
    wget -q https://buildroot.org/downloads/buildroot-${BUILDROOT_VERSION}.tar.gz
    tar xf buildroot-${BUILDROOT_VERSION}.tar.gz --strip-components=1
    rm buildroot-${BUILDROOT_VERSION}.tar.gz
else
    echo "[1/6] Buildroot 소스 이미 존재함 (스킵)"
fi

# [패치] Buildroot git 다운로더에 shallow clone 지원 추가
# 원본 git 다운로더는 항상 전체 히스토리를 fetch → 매우 느림
# BR2_GIT_FETCH_DEPTH 환경변수로 --depth 옵션을 주입하는 패치를 적용
_GIT_DL="support/download/git"
if ! grep -q "BR2_GIT_FETCH_DEPTH" "${_GIT_DL}" 2>/dev/null; then
    echo "[1b/6] git 다운로더 shallow-clone 패치 적용 중..."
    python3 - "${_GIT_DL}" <<'PYEOF'
import sys, re

path = sys.argv[1]
with open(path) as f:
    src = f.read()

# 1) "Fetching all references" 출력 직후 깊이 변수 삽입
old1 = 'printf "Fetching all references\\n"\n_git fetch origin\n_git fetch origin -t'
new1 = ('printf "Fetching all references (depth=${BR2_GIT_FETCH_DEPTH:-1})\\n"\n'
        '_BR2_DEPTH_OPT=""; [ -n "${BR2_GIT_FETCH_DEPTH:-1}" ] && _BR2_DEPTH_OPT="--depth=${BR2_GIT_FETCH_DEPTH:-1}"\n'
        '_git fetch ${_BR2_DEPTH_OPT} origin\n'
        '_git fetch ${_BR2_DEPTH_OPT} origin -t')

# 2) 특수 ref fetch에도 depth 적용
old2 = "_git fetch origin \"'${cset}:${cset}'\""
new2 = "_git fetch ${_BR2_DEPTH_OPT} origin \"'${cset}:${cset}'\""

src = src.replace(old1, new1, 1)
src = src.replace(old2, new2, 1)

with open(path, 'w') as f:
    f.write(src)
print("패치 완료")
PYEOF
else
    echo "[1b/6] git 다운로더 패치 이미 적용됨 (스킵)"
fi

# 다운로드 캐시 디렉토리 연결
echo "[2/6] 다운로드 캐시 디렉토리 설정..."
mkdir -p /home/builder/dl
ln -sfn /home/builder/dl dl

# 커스텀 defconfig 복사
echo "[3/6] 커스텀 설정 파일 복사 (${DEFCONFIG})..."
cp /home/builder/configs/${DEFCONFIG} configs/

# board 디렉토리 복사 (--delete로 호스트에서 삭제된 파일도 반영)
echo "[4/6] 보드 설정 파일 복사 (board/${DEVICE})..."
mkdir -p board/${DEVICE}
rsync -a --delete /home/builder/board/${DEVICE}/ board/${DEVICE}/

# br2-external 연결
echo "[4b/6] BR2_EXTERNAL 설정..."
BR2_EXTERNAL_PATH=/home/builder/br2-external

# 버전 파일 생성
mkdir -p board/${DEVICE}/rootfs-overlay/etc
echo "${VERSION}" > board/${DEVICE}/rootfs-overlay/etc/retropangui-version

# Buildroot 빌드 실행
echo "[5/6] Buildroot 빌드 시작..."
echo "  - defconfig 로드 중..."
rm -f output/.config
rm -f output/build/freeimage-3180/.stamp_built output/build/freeimage-3180/.stamp_staging_installed output/build/freeimage-3180/.stamp_target_installed
make BR2_EXTERNAL="${BR2_EXTERNAL_PATH}" ${DEFCONFIG}

# common_drivers 서브모듈 준비 (커널 추출 후, 빌드 전)
echo "  - 커널 소스 추출 중..."
make BR2_EXTERNAL="${BR2_EXTERNAL_PATH}" linux-extract

LINUX_BUILD_DIR=$(ls -d output/build/linux-* 2>/dev/null | head -1)
if [ -n "${LINUX_BUILD_DIR}" ] && [ -f "${LINUX_BUILD_DIR}/.gitmodules" ]; then
    echo "  - 커널 서브모듈 클론 중..."
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*path[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            submod_path="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^[[:space:]]*url[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            submod_url="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^[[:space:]]*branch[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            submod_branch="${BASH_REMATCH[1]}"
            # 디렉토리가 없거나 비어있으면 클론 (타볼 추출 시 빈 디렉토리 생성 대응)
            if [ -n "${submod_path}" ] && [ -z "$(ls -A "${LINUX_BUILD_DIR}/${submod_path}" 2>/dev/null)" ]; then
                echo "    - ${submod_path} 클론 중 (브랜치: ${submod_branch})..."
                rm -rf "${LINUX_BUILD_DIR}/${submod_path}"
                git clone --depth=15 -b "${submod_branch}" "${submod_url}" \
                    "${LINUX_BUILD_DIR}/${submod_path}"
                # common_drivers: r54p1 DDK(ba6471e firmware와 불호환)가 추가되기 전
                # r44p1-01eac0이 마지막으로 있었던 커밋(HEAD에서 11번째)으로 고정
                if [ "${submod_path}" = "common_drivers" ]; then
                    git -C "${LINUX_BUILD_DIR}/${submod_path}" \
                        checkout 8f02b4a0ec2e7500e1b1cbc5277108bf67adb00f
                fi
            else
                echo "    - ${submod_path} 이미 존재함 (스킵)"
            fi
            submod_path=""; submod_url=""; submod_branch=""
        fi
    done < "${LINUX_BUILD_DIR}/.gitmodules"
fi

# common_drivers DTS를 Buildroot가 찾는 두 경로 모두 symlink 연결
# - arch/arm64/boot/dts/amlogic  (커널 빌드 시스템용)
# - arch/arm64/boot/amlogic      (Buildroot DTB install용: BR2_LINUX_KERNEL_INTREE_DTS_NAME 경로)
if [ -n "${LINUX_BUILD_DIR}" ]; then
    AMLOGIC_DTS_SRC="${LINUX_BUILD_DIR}/common_drivers/arch/arm64/boot/dts/amlogic"
    if [ -d "${AMLOGIC_DTS_SRC}" ]; then
        AMLOGIC_DTS_DST="${LINUX_BUILD_DIR}/arch/arm64/boot/dts/amlogic"
        if [ ! -e "${AMLOGIC_DTS_DST}" ]; then
            echo "  - DTS symlink 생성 중 (dts/amlogic)..."
            ln -s "../../../../common_drivers/arch/arm64/boot/dts/amlogic" "${AMLOGIC_DTS_DST}"
        fi
        AMLOGIC_BOOT_DST="${LINUX_BUILD_DIR}/arch/arm64/boot/amlogic"
        if [ ! -e "${AMLOGIC_BOOT_DST}" ]; then
            echo "  - DTS symlink 생성 중 (boot/amlogic)..."
            ln -s "../../../common_drivers/arch/arm64/boot/dts/amlogic" "${AMLOGIC_BOOT_DST}"
        fi
    fi
fi

# mali-ddk는 Buildroot 자동 감지가 안 되는 로컬 소스이므로 매번 강제 재빌드
echo "  - mali-ddk 강제 재빌드 (로컬 소스 변경 반영)..."
rm -f output/build/mali-ddk-r44p0/.stamp_built \
      output/build/mali-ddk-r44p0/.stamp_staging_installed \
      output/build/mali-ddk-r44p0/.stamp_target_installed

# gamepad-mgr도 로컬 소스이므로 매번 강제 재빌드 (빌드 디렉토리 통째로 삭제)
echo "  - gamepad-mgr 강제 재빌드 (로컬 소스 변경 반영)..."
rm -rf output/build/gamepad-mgr-*/

# bundled-bgmusic: .mid 파일 변경이 stamp로 감지 안 되므로 install stamp만 삭제
echo "  - bundled-bgmusic 재설치 (BGM 파일 변경 반영)..."
rm -f output/build/bundled-bgmusic-1.0/.stamp_target_installed

echo "  - emulationstation 소스 최신화 중..."
if [ -d "output/build/emulationstation-main/.git" ]; then
    git -C output/build/emulationstation-main fetch --depth=1 origin main 2>&1 || true
    git -C output/build/emulationstation-main reset --hard origin/main 2>&1 || true
    rm -f output/build/emulationstation-main/.stamp_built \
          output/build/emulationstation-main/.stamp_target_installed
fi

JOBS="${BUILD_JOBS:-$(nproc)}"
echo "  - 전체 빌드 시작 (병렬 작업 수: ${JOBS})"
echo "  - 로그: /home/builder/output/build.log"
make BR2_EXTERNAL="${BR2_EXTERNAL_PATH}" -j${JOBS} 2>&1 | tee /home/builder/output/build.log

# 최종 이미지 복사
echo "[6/6] 최종 이미지 생성..."
OUTPUT_IMG="retropangui-${DEVICE}-${VERSION}.img"
if [ -f output/images/sdcard.img ]; then
    cp output/images/sdcard.img /home/builder/output/${OUTPUT_IMG}
    echo ""
    echo "============================================"
    echo "  빌드 성공!"
    echo "  이미지: ${OUTPUT_IMG}"
    echo "  크기: $(du -h /home/builder/output/${OUTPUT_IMG} | cut -f1)"
    echo "============================================"
else
    echo "ERROR: sdcard.img 생성 실패!"
    exit 1
fi
