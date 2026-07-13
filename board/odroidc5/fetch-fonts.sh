#!/bin/bash
# fetch-fonts.sh - 번들 폰트 다운로드 스크립트
#
# 예전엔 폰트 TTF(총 ~24MB)를 rootfs-overlay에 직접 커밋했는데, 저장소
# 용량과 출처 추적성 문제로 mali 블롭과 같은 "빌드 시 다운로드" 방식으로
# 전환(2026-07-13, 바이너리 전수 목록 후속). 아래 URL의 파일들이 기존
# 커밋본과 비트 단위로 일치함을 확인하고 sha256을 고정해둠 - 업스트림이
# 파일을 바꾸면 체크섬 불일치로 빌드가 명시적으로 실패함(조용한 교체 방지).
#
# 사용법: bash board/odroidc5/fetch-fonts.sh   (build.sh가 자동 실행)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FONTS_DIR="${SCRIPT_DIR}/blobs/fonts"
WORK_DIR="$(mktemp -d)"
trap "rm -rf ${WORK_DIR}" EXIT

echo "========================================"
echo "  RETROPANGUI-C5 번들 폰트 다운로드"
echo "========================================"

# 산출물 5종이 모두 있으면 스킵
ALL_PRESENT=1
for f in NanumGothic.ttf NanumGothicBold.ttf NanumBarunGothic.ttf \
         D2Coding-Regular.ttf Pretendard-Regular.ttf; do
    [ -f "${FONTS_DIR}/${f}" ] || ALL_PRESENT=0
done
if [ "${ALL_PRESENT}" = "1" ]; then
    echo "[OK] Fonts already present: ${FONTS_DIR}/"
    echo "     강제 재다운로드: rm -rf ${FONTS_DIR} && bash board/odroidc5/fetch-fonts.sh"
    exit 0
fi

mkdir -p "${FONTS_DIR}"

fetch() { # url sha256 저장이름
    local url="$1" sum="$2" out="${WORK_DIR}/$3"
    echo ">>> 다운로드: $3"
    curl -sL --fail --max-time 300 -o "${out}" "${url}"
    echo "${sum}  ${out}" | sha256sum -c - >/dev/null \
        || { echo "[ERROR] sha256 불일치: $3 - 업스트림이 파일을 바꿨을 수 있음"; exit 1; }
}

# 나눔고딕/볼드 - 네이버 공식 CDN (RA ozone/한글 폴백용, 커밋본과 비트일치 확인)
fetch "https://hangeul.pstatic.net/hangeul_static/webfont/zips/nanum-gothic.zip" \
      "9cea4aa259826001727cdcbed34387acd7924079246f9fbb2bd0d0c650bbd312" nanum-gothic.zip
unzip -o -q "${WORK_DIR}/nanum-gothic.zip" NanumGothic.ttf NanumGothicBold.ttf -d "${WORK_DIR}"

# 나눔바른고딕 - 네이버 공식 CDN (ES UI 폰트)
fetch "https://hangeul.pstatic.net/hangeul_static/webfont/zips/nanum-barun-gothic.zip" \
      "950975a416c20ff7aabfeaf549d741a95f69eaf4a86dce2d7845fab909df6b68" nanum-barun-gothic.zip
unzip -o -q "${WORK_DIR}/nanum-barun-gothic.zip" NanumBarunGothic.ttf -d "${WORK_DIR}"

# D2Coding - 네이버 공식 릴리스 (터미널 고정폭)
fetch "https://github.com/naver/d2codingfont/releases/download/VER1.3.2/D2Coding-Ver1.3.2-20180524.zip" \
      "0f1c9192eac7d56329dddc620f9f1666b707e9c8ed38fe1f988d0ae3e30b24e6" d2coding.zip
unzip -o -q "${WORK_DIR}/d2coding.zip" "D2Coding/D2Coding-Ver1.3.2-20180524.ttf" -d "${WORK_DIR}"

# Pretendard - 공식 릴리스 (UI 산세리프)
fetch "https://github.com/orioncactus/pretendard/releases/download/v1.3.9/Pretendard-1.3.9.zip" \
      "04be351a74d6bf7d60c480a3087e51d185485d35a52023142af1df19eb8c428a" pretendard.zip
unzip -o -q "${WORK_DIR}/pretendard.zip" "public/static/alternative/Pretendard-Regular.ttf" -d "${WORK_DIR}"

install -m 0644 "${WORK_DIR}/NanumGothic.ttf"      "${FONTS_DIR}/NanumGothic.ttf"
install -m 0644 "${WORK_DIR}/NanumGothicBold.ttf"  "${FONTS_DIR}/NanumGothicBold.ttf"
install -m 0644 "${WORK_DIR}/NanumBarunGothic.ttf" "${FONTS_DIR}/NanumBarunGothic.ttf"
install -m 0644 "${WORK_DIR}/D2Coding/D2Coding-Ver1.3.2-20180524.ttf" "${FONTS_DIR}/D2Coding-Regular.ttf"
install -m 0644 "${WORK_DIR}/public/static/alternative/Pretendard-Regular.ttf" "${FONTS_DIR}/Pretendard-Regular.ttf"

echo "[OK] 폰트 5종 준비 완료: ${FONTS_DIR}/"
