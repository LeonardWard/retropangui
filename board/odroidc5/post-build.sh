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
    for lib in \
        libGLESv1_CM.so libGLESv1_CM.so.1 \
        libwayland-egl.so libwayland-egl.so.1 \
        libOpenCL.so libOpenCL.so.1 \
        libvulkan.so libvulkan.so.1; do
        ln -sf libMali.so "${LIBPATH}/${lib}"
    done
    echo ">>> libMali 심볼릭 링크 완료"
fi

# ksmbd 계정 초기화 (pangui/odroid)
# ksmbdpwd.db가 없거나 비어있으면 ksmbd가 인증을 처리하지 못함
KSMBD_PWDB="${TARGET_DIR}/etc/ksmbd/ksmbdpwd.db"
if [ ! -s "${KSMBD_PWDB}" ]; then
    if command -v ksmbd.adduser >/dev/null 2>&1; then
        echo ">>> ksmbd 계정 생성 중 (pangui/odroid)..."
        ksmbd.adduser -P "${KSMBD_PWDB}" -a pangui -p odroid 2>/dev/null || true
    fi
fi

# 테마 복사 (빌드 시 호스트에서 마운트된 테마 → bundled-themes 갱신)
THEMES_SRC="/home/builder/themes"
THEMES_DST="${TARGET_DIR}/opt/retropangui/themes"
if [ -d "${THEMES_SRC}" ] && [ -n "$(ls -A "${THEMES_SRC}" 2>/dev/null)" ]; then
    echo ">>> 테마 복사 중: ${THEMES_SRC} → ${THEMES_DST}"
    mkdir -p "${THEMES_DST}"
    cp -r "${THEMES_SRC}/." "${THEMES_DST}/"
else
    echo ">>> 테마 없음 (스킵): ${THEMES_SRC}"
fi

# es_systems.xml 생성
echo ">>> es_systems.xml 생성 중..."
python3 "${BOARD_DIR}/generate_es_systems.py" \
    --systems   "${BOARD_DIR}/systems.json" \
    --output    "${TARGET_DIR}/etc/emulationstation/es_systems.xml" \
    --roms-path "/retropangui/share/roms" \
    --retroarch "/opt/retropangui/bin/retroarch" \
    --config    "/retropangui/share/system/retroarch/retroarch.cfg"

echo ">>> post-build.sh 완료"
