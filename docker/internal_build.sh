#!/bin/bash
# internal_build.sh - Docker 컨테이너 내부에서 실행되는 빌드 스크립트

set -eo pipefail

BUILDROOT_VERSION="${BUILDROOT_VERSION:-2024.02.1}"
DEVICE="${DEVICE:-odroidc5}"
VERSION="${VERSION:-1.0.0}"
PARTIAL="${PARTIAL:-0}"
BUILD_IMG="${BUILD_IMG:-1}"
BUILD_OTA="${BUILD_OTA:-0}"
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
if   [ "$BUILD_IMG" = "1" ] && [ "$BUILD_OTA" = "1" ]; then _MODE="전체빌드 (img + squashfs)"
elif [ "$BUILD_IMG" = "1" ]; then _MODE="전체빌드 (img만)"
elif [ "$BUILD_OTA" = "1" ]; then _MODE="OTA 빠른빌드 (squashfs만)"
fi
[ "$PARTIAL" = "1" ] && _MODE="부분빌드"
echo "  모드: ${_MODE}"
echo "  defconfig: ${DEFCONFIG}"
echo "============================================"

# OTA 빠른빌드: 전체 패키지 증분 빌드(defconfig 재동기화 포함) + squashfs만 생성
# (img 없음) - 이름은 "빠른빌드"지만 실제로는 전체 make를 돌림. Buildroot의
# 패키지별 스탬프 파일이 이미 빌드된 것들을 스킵해주므로 체감 속도는 여전히
# 빠름 - 다만 새 패키지 추가 직후 첫 OTA 빌드는 그 패키지들 빌드 시간만큼
# 더 걸림(당연함).
if [ "$BUILD_OTA" = "1" ] && [ "$BUILD_IMG" = "0" ]; then
    BR2_EXTERNAL_PATH=/home/builder/br2-external
    echo "[OTA 빌드] board 파일 복사 중..."
    mkdir -p board/${DEVICE}
    rsync -a --delete /home/builder/board/${DEVICE}/ board/${DEVICE}/
    mkdir -p board/${DEVICE}/rootfs-overlay/etc
    echo "${VERSION}" > board/${DEVICE}/rootfs-overlay/etc/retropangui-version

    # defconfig를 항상 재동기화 — 이 cp가 빠지면 make가 buildroot/configs/
    # 안의 예전 defconfig 사본을 그대로 읽어서, host 쪽 configs/에 새로
    # 추가한 BR2_PACKAGE_*가 있어도 못 봄(2026-07-10, cifs-utils/nfs-utils/
    # noto-cjk-font 세 패키지가 정확히 이 이유로 두 번이나 누락된 채
    # 배포된 적 있음 - 1차 수정에서 make ${DEFCONFIG}만 추가하고 이 cp를
    # 빠뜨렸었음). .config 자체는 buildroot 최상위(output/ 아래가 아님)에
    # 생성됨 - 재생성 자체는 가벼운 작업이라 매번 해도 빌드 시간에 영향
    # 없음, 실제 컴파일은 아래 make가 스탬프 파일로 알아서 증분 처리함.
    echo "[OTA 빌드] defconfig 재동기화 중..."
    cp /home/builder/configs/${DEFCONFIG} configs/
    rm -f .config
    make BR2_EXTERNAL="${BR2_EXTERNAL_PATH}" ${DEFCONFIG}

    # 2026-07-20: 호스트 build.sh가 로컬 ES 클론 커밋 비교로 이미 변경 여부를
    # 판단(ES_SKIP_REFETCH) - 변경 없으면 fetch/reset/스탬프 삭제 전부 스킵.
    if [ "${ES_SKIP_REFETCH:-0}" = "1" ]; then
        echo "[OTA 빌드] emulationstation 변경 없음 - 소스 최신화 스킵"
    else
        echo "[OTA 빌드] emulationstation 소스 최신화 중..."
        if [ -d "output/build/emulationstation-main/.git" ]; then
            git -C output/build/emulationstation-main fetch --depth=1 origin main 2>&1 || true
            git -C output/build/emulationstation-main reset --hard origin/main 2>&1 || true
        fi
        rm -f output/build/emulationstation-main/.stamp_built           output/build/emulationstation-main/.stamp_target_installed
    fi

    # 2026-07-20: freeimage/mali-ddk/retropangui-initramfs/bundled-bgmusic
    # 강제 재빌드는 host의 scripts/detect-stale-package-caches.sh(git 커밋
    # 비교로 실제 변경된 패키지만 캐시 정리)가 docker 실행 전에 이미 처리함
    # - todo-20260720-build-force-clean-audit.html 참고.

    # emulationstation만 targeted로 빌드하던 걸 전체 make로 교체 —
    # defconfig에 새로 추가된 패키지(위 예시들)가 targeted 빌드 목록에
    # 없으면 조용히 누락되는 문제를 근본적으로 막기 위함. Buildroot는
    # 패키지별 스탬프 파일로 증분 빌드하므로, 이미 빌드된 패키지는
    # 이 전체 make에서도 빠르게 스킵됨 - ES만 변경된 흔한 경우엔
    # 예전 targeted 방식과 체감 속도 차이 거의 없고, 새 패키지가
    # 추가된 경우엔 자동으로 같이 빌드됨(retropangui-initramfs,
    # bundled-roms, rootfs-squashfs도 이 안에서 함께 처리되므로
    # 이후의 개별 make 호출은 불필요해서 제거).
    echo "[OTA 빌드] 전체 빌드 중 (defconfig에 켜진 모든 패키지, 증분)..."
    JOBS="${BUILD_JOBS:-$(nproc)}"
    make BR2_EXTERNAL="${BR2_EXTERNAL_PATH}" -j${JOBS} 2>&1 | tee /home/builder/output/build-ota.log

    # 위 정리 작업이 target/ 안의 파일을 직접 지우므로, squashfs를
    # 다시 봉인해서 정리 결과를 반영 (전체 make가 이미 한 번 만들어
    # 둔 squashfs는 정리 전 상태라 그대로 쓰면 안 됨)
    echo "[OTA 빌드] squashfs 재생성 중 (정리 후 반영)..."
    make BR2_EXTERNAL="${BR2_EXTERNAL_PATH}" rootfs-squashfs 2>&1 | tee -a /home/builder/output/build-ota.log

    OUTPUT_SQ="retropangui-${DEVICE}-${VERSION}.squashfs"
    OUTPUT_INITRAMFS="retropangui-${DEVICE}-${VERSION}.initramfs.cpio.gz"
    if [ -f output/images/rootfs.squashfs ]; then
        cp output/images/rootfs.squashfs /home/builder/output/${OUTPUT_SQ}
        sha256sum /home/builder/output/${OUTPUT_SQ} | awk '{print $1}' \
            > /home/builder/output/${OUTPUT_SQ}.sha256
        cp output/images/initramfs.cpio.gz /home/builder/output/${OUTPUT_INITRAMFS}
        sha256sum /home/builder/output/${OUTPUT_INITRAMFS} | awk '{print $1}' \
            > /home/builder/output/${OUTPUT_INITRAMFS}.sha256
        echo "============================================"
        echo "  OTA 빌드 성공!"
        echo "  squashfs:  ${OUTPUT_SQ} ($(du -h /home/builder/output/${OUTPUT_SQ} | cut -f1))"
        echo "  initramfs: ${OUTPUT_INITRAMFS} ($(du -h /home/builder/output/${OUTPUT_INITRAMFS} | cut -f1))"
        echo "  SHA256 squashfs:  $(cat /home/builder/output/${OUTPUT_SQ}.sha256)"
        echo "  SHA256 initramfs: $(cat /home/builder/output/${OUTPUT_INITRAMFS}.sha256)"
        echo "============================================"
    else
        echo "ERROR: rootfs.squashfs 생성 실패!"
        exit 1
    fi
    exit 0
fi

# 부분 빌드: board 파일 복사 + 증분 빌드 + 이미지 재패킹만 수행
if [ "$PARTIAL" = "1" ]; then
    BR2_EXTERNAL_PATH=/home/builder/br2-external
    echo "[부분 빌드] board 파일 복사 중..."
    mkdir -p board/${DEVICE}
    rsync -a --delete /home/builder/board/${DEVICE}/ board/${DEVICE}/
    mkdir -p board/${DEVICE}/rootfs-overlay/etc
    echo "${VERSION}" > board/${DEVICE}/rootfs-overlay/etc/retropangui-version

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

# [패치] alsa-plugins에 pulse 플러그인 조건부 활성화 (2026-07-17, PulseAudio 전환)
# 상류 buildroot는 --disable-pulseaudio 하드코딩 - PULSEAUDIO 활성 시
# pcm/ctl pulse 플러그인이 있어야 ALSA 앱(VLC/RetroArch/fluidsynth/amixer)이
# asound.conf의 default를 통해 PA로 라우팅됨(todo-20260716-pulseaudio-migration.html).
# buildroot/는 gitignore(자동 다운로드) 대상이라 여기서 멱등 패치로 재현.
_ALSA_PLUGINS_MK="package/alsa-plugins/alsa-plugins.mk"
if grep -q -- "--disable-pulseaudio" "${_ALSA_PLUGINS_MK}" 2>/dev/null && \
   ! grep -q "BR2_PACKAGE_PULSEAUDIO" "${_ALSA_PLUGINS_MK}" 2>/dev/null; then
    echo "[1c/6] alsa-plugins pulse 플러그인 조건부 활성화 패치 적용 중..."
    python3 - "${_ALSA_PLUGINS_MK}" <<'PYEOF'
import sys

path = sys.argv[1]
with open(path) as f:
    src = f.read()

src = src.replace("\t--disable-pulseaudio \\\n", "", 1)
old = "\t--with-speex=no\n"
new = ("\t--with-speex=no\n"
       "\n"
       "# RetroPangUI: PULSEAUDIO 활성 시 pulse 플러그인 켬 (internal_build.sh가 적용)\n"
       "ifeq ($(BR2_PACKAGE_PULSEAUDIO),y)\n"
       "ALSA_PLUGINS_CONF_OPTS += --enable-pulseaudio\n"
       "ALSA_PLUGINS_DEPENDENCIES += pulseaudio\n"
       "else\n"
       "ALSA_PLUGINS_CONF_OPTS += --disable-pulseaudio\n"
       "endif\n")
src = src.replace(old, new, 1)

with open(path, 'w') as f:
    f.write(src)
print("패치 완료")
PYEOF
else
    echo "[1c/6] alsa-plugins 패치 이미 적용됨 (스킵)"
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
make BR2_EXTERNAL="${BR2_EXTERNAL_PATH}" ${DEFCONFIG}

# 2026-07-20: freeimage 강제 삭제 + 커널(linux-custom) 조건부 재추출 로직은
# host의 scripts/detect-stale-package-caches.sh(git 커밋 비교로 실제 변경된
# 패키지만 캐시 정리, board/${DEVICE}/patches/linux/*도 포함)가 docker 실행
# 전에 이미 처리함 - todo-20260720-build-force-clean-audit.html 참고.

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

# 2026-07-20: mali-ddk/alsa-utils 강제 재빌드는 host의
# scripts/detect-stale-package-caches.sh(git 커밋 비교로 실제 변경된 패키지만
# 캐시 정리)가 docker 실행 전에 이미 처리함 - alsa-utils는 defconfig의
# BR2_PACKAGE_ALSA_UTILS_* 옵션이 바뀔 때만, mali-ddk는 br2-external/package/
# mali-ddk/ 아래 파일이 바뀔 때만 정리됨. todo-20260720-build-force-clean-audit.html 참고.

# 2026-07-20: 호스트 build.sh가 로컬 ES 클론 커밋 비교로 이미 변경 여부를
# 판단(ES_SKIP_REFETCH) - 변경 없으면 fetch/reset/스탬프 삭제 전부 스킵.
if [ "${ES_SKIP_REFETCH:-0}" = "1" ]; then
    echo "  - emulationstation 변경 없음 - 소스 최신화 스킵"
elif [ -d "output/build/emulationstation-main/.git" ]; then
    echo "  - emulationstation 소스 최신화 중..."
    git -C output/build/emulationstation-main fetch --depth=1 origin main 2>&1 || true
    git -C output/build/emulationstation-main reset --hard origin/main 2>&1 || true
    rm -f output/build/emulationstation-main/.stamp_built \
          output/build/emulationstation-main/.stamp_target_installed
fi

JOBS="${BUILD_JOBS:-$(nproc)}"
echo "  - 전체 빌드 시작 (병렬 작업 수: ${JOBS})"
echo "  - 로그: /home/builder/output/build.log"
make BR2_EXTERNAL="${BR2_EXTERNAL_PATH}" -j${JOBS} 2>&1 | tee /home/builder/output/build.log

# 최종 결과물 복사
echo "[6/6] 최종 결과물 생성..."
OUTPUT_IMG="retropangui-${DEVICE}-${VERSION}.img"
OUTPUT_SQ="retropangui-${DEVICE}-${VERSION}.squashfs"

if [ "$BUILD_IMG" = "1" ]; then
    if [ -f output/images/sdcard.img ]; then
        cp output/images/sdcard.img /home/builder/output/${OUTPUT_IMG}
        echo "  이미지: ${OUTPUT_IMG} ($(du -h /home/builder/output/${OUTPUT_IMG} | cut -f1))"
    else
        echo "ERROR: sdcard.img 생성 실패!"
        exit 1
    fi
fi

if [ "$BUILD_OTA" = "1" ]; then
    if [ -f output/images/rootfs.squashfs ]; then
        cp output/images/rootfs.squashfs /home/builder/output/${OUTPUT_SQ}
        sha256sum /home/builder/output/${OUTPUT_SQ} | awk '{print $1}' \
            > /home/builder/output/${OUTPUT_SQ}.sha256
        echo "  squashfs: ${OUTPUT_SQ} ($(du -h /home/builder/output/${OUTPUT_SQ} | cut -f1))"
        echo "  SHA256:   $(cat /home/builder/output/${OUTPUT_SQ}.sha256)"
        # initramfs도 항상 함께 산출 - 이 복사가 OTA 전용 경로(--ota)에만 있고
        # 전체 빌드 경로엔 빠져 있어서, ota.sh push가 output/의 낡은 initramfs를
        # 계속 서빙 → init 스크립트 수정(공장초기화 정리 등)이 기기에 영영 안
        # 가는 문제가 있었음(2026-07-17 실기기 확인: /boot의 initramfs가 7/16
        # 빌드본에 멈춰 있었음).
        OUTPUT_INITRAMFS="retropangui-${DEVICE}-${VERSION}.initramfs.cpio.gz"
        cp output/images/initramfs.cpio.gz /home/builder/output/${OUTPUT_INITRAMFS}
        sha256sum /home/builder/output/${OUTPUT_INITRAMFS} | awk '{print $1}' \
            > /home/builder/output/${OUTPUT_INITRAMFS}.sha256
        echo "  initramfs: ${OUTPUT_INITRAMFS} ($(du -h /home/builder/output/${OUTPUT_INITRAMFS} | cut -f1))"
    else
        echo "ERROR: rootfs.squashfs 생성 실패!"
        exit 1
    fi
fi

echo ""
echo "============================================"
echo "  빌드 성공!"
echo "============================================"
