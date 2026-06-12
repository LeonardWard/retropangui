#!/bin/bash
# post-build.sh - Buildroot 빌드 후 RootFS 커스터마이징

set -e

TARGET_DIR=$1
BOARD_DIR=$(dirname "$0")
DEVICE="${DEVICE:-odroidc5}"
VERSION="${VERSION:-1.0.0}"

echo ">>> RETROPANGUI post-build script 실행 (device: ${DEVICE}, version: ${VERSION})"

# /etc/hostname 설정
echo "retropangui-c5" > "${TARGET_DIR}/etc/hostname"

# os-release 덮어쓰기 (Buildroot 기본값 대체)
mkdir -p "${TARGET_DIR}/usr/lib"
cat > "${TARGET_DIR}/usr/lib/os-release" << EOF
NAME="RetroPangui"
VERSION="${VERSION}"
ID=retropangui
ID_LIKE=buildroot
VERSION_ID=${VERSION}
PRETTY_NAME="RetroPangui ${VERSION} (${DEVICE})"
HOME_URL="https://github.com/pangui/retropangui"
EOF
ln -sf ../usr/lib/os-release "${TARGET_DIR}/etc/os-release"

# /etc/issue 배너
cat > "${TARGET_DIR}/etc/issue" << 'EOF'
   ____ ____        ____                             _
  / ___|___ \ _ __ / ___| _   _ _ __   __ _ _   _(_)
 | |     __) |  _ \| |  | | | | |  _ \ / _  | | | | |
 | |___ / __/| |_) | |__| |_| | | |_) | (_| | |_| | |
  \____|_____| .__/ \____\__. |_|  __/ \__. |\__. |_|
             |_|         |___/  |_|    |___/ |___/

RETROPANGUI-C5 Retro Gaming OS
Powered by Buildroot

EOF

# 기본 네트워크 설정 (DHCP)
mkdir -p "${TARGET_DIR}/etc/network"
cat > "${TARGET_DIR}/etc/network/interfaces" << 'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
	hostname retropangui-c5
EOF


# 기본 사용자 비밀번호 설정 (root:odroid)
# 실제 배포 시에는 변경 필요!
HASH=$(echo "odroid" | openssl passwd -6 -stdin)
sed -i "s|^root:[^:]*:|root:${HASH}:|" "${TARGET_DIR}/etc/shadow"

# libMali 심볼릭 링크 생성
LIBPATH="${TARGET_DIR}/usr/lib"
if [ -f "${LIBPATH}/libMali.so" ]; then
    echo ">>> libMali 심볼릭 링크 생성 중..."

    # mali-ddk 래퍼를 거쳐야 하는 라이브러리: 래퍼 .so.X.Y.Z를 가리키도록 강제 설정
    # (mali-ddk 패키지가 libMali.so를 직접 가리키는 심볼릭 링크를 만들 수 있으므로 덮어씀)
    [ -f "${LIBPATH}/libEGL.so.1.0.0" ]    && ln -sf libEGL.so.1.0.0    "${LIBPATH}/libEGL.so"
    [ -f "${LIBPATH}/libEGL.so.1.0.0" ]    && ln -sf libEGL.so.1.0.0    "${LIBPATH}/libEGL.so.1"
    [ -f "${LIBPATH}/libgbm.so.1.0.0" ]    && ln -sf libgbm.so.1.0.0    "${LIBPATH}/libgbm.so"
    [ -f "${LIBPATH}/libgbm.so.1.0.0" ]    && ln -sf libgbm.so.1.0.0    "${LIBPATH}/libgbm.so.1"
    [ -f "${LIBPATH}/libGLESv2.so.2.0.0" ] && ln -sf libGLESv2.so.2.0.0 "${LIBPATH}/libGLESv2.so"
    [ -f "${LIBPATH}/libGLESv2.so.2.0.0" ] && ln -sf libGLESv2.so.2.0.0 "${LIBPATH}/libGLESv2.so.2"

    # libMali.so를 직접 가리켜도 되는 라이브러리
    # 주의: libvulkan은 여기 넣으면 안 됨 — Mali 블롭은 Vulkan 로더 진입점
    # (vkGetInstanceProcAddr)을 export하지 않아 "broken loader"로 실패함.
    # vulkan-loader 패키지의 정식 로더(libvulkan.so.1.3.x)가 그대로 남아야 하고,
    # Mali 연결은 ICD(/usr/share/vulkan/icd.d/mali.json → libMali.so)가 담당.
    for lib in \
        libGLESv1_CM.so libGLESv1_CM.so.1 \
        libwayland-egl.so libwayland-egl.so.1 \
        libOpenCL.so libOpenCL.so.1; do
        ln -sf libMali.so "${LIBPATH}/${lib}"
    done
    echo ">>> libMali 심볼릭 링크 완료"
fi

# libvulkan: 정식 로더로 강제 복원
# target/은 증분 빌드라 과거 빌드가 만든 libvulkan→libMali 링크가 지워지지 않고
# 이미지에 남을 수 있음 (0.4-18-gc3b4ebc 회귀 원인). 생성을 안 하는 것만으로는
# 부족하므로 실제 로더 파일(libvulkan.so.1.3.x)을 찾아 링크를 명시적으로 덮어쓴다.
for f in "${LIBPATH}"/libvulkan.so.1.*; do
    if [ -f "${f}" ] && [ ! -L "${f}" ]; then
        VK_LOADER=$(basename "${f}")
        echo ">>> libvulkan.so.1 → ${VK_LOADER} 강제 복원"
        ln -sf "${VK_LOADER}" "${LIBPATH}/libvulkan.so.1"
        ln -sf libvulkan.so.1 "${LIBPATH}/libvulkan.so"
        break
    fi
done

# ksmbd 계정 초기화 (pangui/odroid)
# ksmbdpwd.db가 없거나 비어있으면 ksmbd가 인증을 처리하지 못함
KSMBD_PWDB="${TARGET_DIR}/etc/ksmbd/ksmbdpwd.db"
if [ ! -s "${KSMBD_PWDB}" ]; then
    if command -v ksmbd.adduser >/dev/null 2>&1; then
        echo ">>> ksmbd 계정 생성 중 (pangui/odroid)..."
        ksmbd.adduser -P "${KSMBD_PWDB}" -a pangui -p odroid 2>/dev/null || true
    fi
fi

# 테마 다운로드 (GitHub → /opt/retropangui/themes/)
# S95retropangui 부팅 시 /retropangui/share/system/emulationstation/themes/ 로 복사됨
THEMES_DST="${TARGET_DIR}/opt/retropangui/themes"
SLATE_REPO="https://github.com/LeonardWard/retropangui-slate"
SLATE_THEME_NAME="retropangui-slate"

mkdir -p "${THEMES_DST}"

echo ">>> 테마 다운로드 중: ${SLATE_REPO}"
TMPDIR=$(mktemp -d)
if wget -q "${SLATE_REPO}/archive/refs/heads/main.tar.gz" -O "${TMPDIR}/theme.tar.gz"; then
    tar xzf "${TMPDIR}/theme.tar.gz" -C "${TMPDIR}"
    # tar 압축 해제 시 폴더명: retropangui-slate-main/retropangui-slate/
    # 레포 루트가 곧 테마 폴더이므로 retropangui-slate-main을 통째로 이동
    if [ -d "${TMPDIR}/retropangui-slate-main" ]; then
        rm -rf "${THEMES_DST}/${SLATE_THEME_NAME}"
        cp -r "${TMPDIR}/retropangui-slate-main" "${THEMES_DST}/${SLATE_THEME_NAME}"
        echo ">>> 테마 설치 완료: ${THEMES_DST}/${SLATE_THEME_NAME}"
    else
        echo ">>> WARNING: 테마 폴더를 찾지 못함 (tar 구조 확인 필요)"
    fi
else
    echo ">>> WARNING: 테마 다운로드 실패 (네트워크 확인)"
fi
rm -rf "${TMPDIR}"

# es_systems.xml 생성
echo ">>> es_systems.xml 생성 중..."
python3 "${BOARD_DIR}/generate_es_systems.py" \
    --systems   "${BOARD_DIR}/systems.json" \
    --output    "${TARGET_DIR}/etc/emulationstation/es_systems.xml" \
    --roms-path "/retropangui/share/roms" \
    --retroarch "/opt/retropangui/bin/retroarch" \
    --config    "/retropangui/share/system/retroarch/retroarch.cfg"

echo ">>> post-build.sh 완료"
