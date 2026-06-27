#!/bin/bash
# ota.sh - OTA squashfs 배포 및 파일서버
#
# 사용법:
#   ota.sh push <squashfs> [--serv] [버전]  # 배포 (+ 서버 시작)
#   ota.sh serve [--port N]                  # 서버 시작
#
# 예:
#   ota.sh push retropangui-odroidc5-0.15.squashfs
#   ota.sh push retropangui-odroidc5-0.15.squashfs --serv  (또는 -s)
#   ota.sh serve
#   ota.sh serve --port 9000
#
# 파일서버 디렉토리: ~/scripts/ota-server/
# C5 접근 URL: http://<이 PC의 IP>:8765/

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OTA_SERVER_DIR="${HOME}/scripts/ota-server"
DEVICE="${DEVICE:-odroidc5}"
PORT=8765
SERVE=0

SUBCMD="${1:-}"
shift || true

# 플래그 파싱
POSITIONAL=()
for arg in "$@"; do
    case "$arg" in
        --serv|-s)   SERVE=1 ;;
        --port)      shift; PORT="$1" ;;
        --port=*)    PORT="${arg#*=}" ;;
        *)           POSITIONAL+=("$arg") ;;
    esac
done
set -- "${POSITIONAL[@]+"${POSITIONAL[@]}"}"

# ─── serve 함수 ────────────────────────────────────────────────────
_serve() {
    if [ ! -d "${OTA_SERVER_DIR}" ]; then
        echo "ERROR: OTA 서버 디렉토리가 없습니다: ${OTA_SERVER_DIR}"
        echo "먼저 squashfs를 배포하세요:"
        echo "  ota.sh push output/retropangui-${DEVICE}-VERSION.squashfs"
        exit 1
    fi

    LOCAL_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[^ ]+' || hostname -I | awk '{print $1}')
    VERSION=$(cat "${OTA_SERVER_DIR}/version" 2>/dev/null || echo "(없음)")
    PUSH_SOURCE=$(grep '^source=' "${OTA_SERVER_DIR}/push-info" 2>/dev/null | cut -d= -f2- || echo "(없음)")
    PUSH_TIME=$(grep '^pushed=' "${OTA_SERVER_DIR}/push-info" 2>/dev/null | cut -d= -f2- || echo "(없음)")

    echo "============================================"
    echo "  RetroPangUI OTA 파일서버 (개발용)"
    echo "  현재 버전: ${VERSION}"
    echo "  소스 파일: ${PUSH_SOURCE}"
    echo "  배포 시각: ${PUSH_TIME}"
    echo ""
    echo "  C5 설정 URL:"
    echo "    http://${LOCAL_IP}:${PORT}"
    echo ""
    echo "  버전 확인: http://${LOCAL_IP}:${PORT}/version"
    echo "  squashfs:  http://${LOCAL_IP}:${PORT}/retropangui-${DEVICE}.squashfs"
    echo "============================================"
    echo ""
    echo "  Ctrl+C로 종료"
    echo ""

    cd "${OTA_SERVER_DIR}"
    exec python3 -m http.server "${PORT}"
}

# ─── 서브커맨드 분기 ────────────────────────────────────────────────
case "${SUBCMD}" in
    serve)
        _serve
        ;;
    push)
        ;;
    --help|-h|"")
        sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
        exit 0
        ;;
    *)
        echo "ERROR: 알 수 없는 명령 '${SUBCMD}'"
        echo "사용법: ota.sh push <squashfs> | serve [--port N]"
        exit 1
        ;;
esac

# ─── 배포 모드 ─────────────────────────────────────────────────────
SQ_FILE="$(realpath "${1:?squashfs 파일 경로를 지정하세요}")"
if [ ! -f "${SQ_FILE}" ]; then
    echo "ERROR: 파일이 없습니다: ${SQ_FILE}"
    exit 1
fi

# 버전: 2번째 인자 > 파일명에서 추출 > git describe 순으로 결정
# $2가 --로 시작하면 플래그 오타이므로 VERSION으로 쓰지 않음
if [ -n "${2:-}" ] && [ "${2#--}" = "${2}" ]; then
    VERSION="$2"
else
    BASENAME="$(basename "${SQ_FILE}" .squashfs)"
    EXTRACTED="${BASENAME##retropangui-${DEVICE}-}"
    if [ -n "${EXTRACTED}" ] && [ "${EXTRACTED}" != "${BASENAME}" ]; then
        VERSION="${EXTRACTED}"
    elif VERSION="$(git -C "${SCRIPT_DIR}" describe --tags 2>/dev/null)"; then
        : # git describe 성공
    else
        VERSION="unknown"
    fi
fi

mkdir -p "${OTA_SERVER_DIR}"

echo ">>> OTA 파일서버 배포 중..."
echo "    버전: ${VERSION}"
echo "    소스: ${SQ_FILE}"
echo "    대상: ${OTA_SERVER_DIR}/"

cp "${SQ_FILE}" "${OTA_SERVER_DIR}/retropangui-${DEVICE}.squashfs"

SQ_SHA256="${SQ_FILE}.sha256"
if [ -f "${SQ_SHA256}" ]; then
    cp "${SQ_SHA256}" "${OTA_SERVER_DIR}/retropangui-${DEVICE}.squashfs.sha256"
else
    echo "    SHA256 계산 중..."
    sha256sum "${OTA_SERVER_DIR}/retropangui-${DEVICE}.squashfs" \
        | awk '{print $1}' \
        > "${OTA_SERVER_DIR}/retropangui-${DEVICE}.squashfs.sha256"
fi

echo "${VERSION}" > "${OTA_SERVER_DIR}/version"
printf 'version=%s\nsource=%s\npushed=%s\n' \
    "${VERSION}" "${SQ_FILE}" "$(date '+%Y-%m-%d %H:%M:%S')" \
    > "${OTA_SERVER_DIR}/push-info"

echo ""
echo "============================================"
echo "  OTA 배포 완료"
echo "  버전: ${VERSION}"
echo "  크기: $(du -h "${OTA_SERVER_DIR}/retropangui-${DEVICE}.squashfs" | cut -f1)"
echo "  SHA256: $(cat "${OTA_SERVER_DIR}/retropangui-${DEVICE}.squashfs.sha256")"
echo "============================================"

if [ "${SERVE}" -eq 1 ]; then
    _serve
fi
