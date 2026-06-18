#!/bin/bash
# serve-ota.sh - 로컬 OTA 파일서버 (개발/테스트용)
#
# C5에서 접근할 URL:
#   버전 확인: http://<이 PC의 IP>:8765/version
#   squashfs:  http://<이 PC의 IP>:8765/retropangui-odroidc5.squashfs
#   sha256:    http://<이 PC의 IP>:8765/retropangui-odroidc5.squashfs.sha256
#
# 사용법:
#   bash scripts/serve-ota.sh          # 기본 포트 8765
#   bash scripts/serve-ota.sh 9000     # 포트 지정

set -e

PORT="${1:-8765}"
OTA_SERVER_DIR="${HOME}/scripts/ota-server"

if [ ! -d "${OTA_SERVER_DIR}" ]; then
    echo "ERROR: OTA 서버 디렉토리가 없습니다: ${OTA_SERVER_DIR}"
    echo "먼저 squashfs를 배포하세요:"
    echo "  bash scripts/push-ota.sh output/retropangui-odroidc5-VERSION.squashfs"
    exit 1
fi

# 이 PC의 LAN IP 출력
LOCAL_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[^ ]+' || hostname -I | awk '{print $1}')
VERSION=$(cat "${OTA_SERVER_DIR}/version" 2>/dev/null || echo "(없음)")

echo "============================================"
echo "  RetroPangUI OTA 파일서버 (개발용)"
echo "  서빙 디렉토리: ${OTA_SERVER_DIR}"
echo "  현재 버전: ${VERSION}"
echo ""
echo "  C5 설정 URL:"
echo "    http://${LOCAL_IP}:${PORT}"
echo ""
echo "  버전 확인: http://${LOCAL_IP}:${PORT}/version"
echo "  squashfs:  http://${LOCAL_IP}:${PORT}/retropangui-odroidc5.squashfs"
echo "============================================"
echo ""
echo "  Ctrl+C로 종료"
echo ""

cd "${OTA_SERVER_DIR}"
python3 -m http.server "${PORT}"
