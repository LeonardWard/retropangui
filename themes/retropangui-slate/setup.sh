#!/bin/bash
# retropangui-slate 테마 에셋 다운로드 스크립트
# 폰트(Inter), 시스템 로고(SVG), 콘솔 아트(PNG)를 다운로드합니다.

set -e

THEME_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_URL="https://raw.githubusercontent.com/fabricecaruso/es-theme-carbon/master"

SYSTEMS=(
  nes snes megadrive genesis psx ps2 dreamcast neogeo gba n64
  arcade mame gb gbc gc saturn sfc famicom pcengine fba
  3do atari2600 c64 msx nds psp coleco mastersystem gamegear
)

echo "=== retropangui-slate 에셋 다운로드 시작 ==="
echo "테마 디렉토리: $THEME_DIR"
echo ""

# ──────────────────────────────────────────────
# 1. Inter 폰트 다운로드
# ──────────────────────────────────────────────
echo "[1/3] Inter 폰트 다운로드 중..."
mkdir -p "$THEME_DIR/_assets/fonts"

FONT_ZIP="/tmp/Inter-4.0.zip"
FONT_URL="https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip"

if command -v curl &>/dev/null; then
  curl -fsSL -o "$FONT_ZIP" "$FONT_URL" || { echo "  폰트 다운로드 실패 (skip)"; FONT_ZIP=""; }
elif command -v wget &>/dev/null; then
  wget -q -O "$FONT_ZIP" "$FONT_URL" || { echo "  폰트 다운로드 실패 (skip)"; FONT_ZIP=""; }
else
  echo "  curl/wget 없음 — 폰트 다운로드 skip"
  FONT_ZIP=""
fi

if [ -n "$FONT_ZIP" ] && [ -f "$FONT_ZIP" ]; then
  TMP_FONT_DIR="/tmp/inter_font_$$"
  mkdir -p "$TMP_FONT_DIR"
  unzip -q "$FONT_ZIP" -d "$TMP_FONT_DIR" || true

  for VARIANT in Regular Bold SemiBold; do
    # Inter 4.0 ZIP 내부 구조: Inter Desktop/Inter-Regular.ttf 등
    FOUND=$(find "$TMP_FONT_DIR" -name "Inter-${VARIANT}.ttf" 2>/dev/null | head -1)
    if [ -n "$FOUND" ]; then
      cp "$FOUND" "$THEME_DIR/_assets/fonts/Inter-${VARIANT}.ttf"
      echo "  Inter-${VARIANT}.ttf 복사 완료"
    else
      echo "  Inter-${VARIANT}.ttf 를 ZIP 안에서 찾지 못함 (skip)"
    fi
  done

  rm -rf "$TMP_FONT_DIR" "$FONT_ZIP"
fi
echo ""

# ──────────────────────────────────────────────
# 2. 시스템 로고 SVG 다운로드
# ──────────────────────────────────────────────
echo "[2/3] 시스템 로고 다운로드 중..."
mkdir -p "$THEME_DIR/_assets/logos"

for SYS in "${SYSTEMS[@]}"; do
  URL="$BASE_URL/$SYS/art/logo.svg"
  DEST="$THEME_DIR/_assets/logos/$SYS.svg"
  if curl -fsSL -o "$DEST" "$URL" 2>/dev/null; then
    echo "  [OK] $SYS.svg"
  else
    echo "  [skip] $SYS logo"
    rm -f "$DEST"
  fi
done
echo ""

# ──────────────────────────────────────────────
# 3. 콘솔 아트(controller.png) 다운로드
# ──────────────────────────────────────────────
echo "[3/3] 콘솔 아트 다운로드 중..."
mkdir -p "$THEME_DIR/_assets/consoles"

for SYS in "${SYSTEMS[@]}"; do
  URL="$BASE_URL/$SYS/art/controller.png"
  DEST="$THEME_DIR/_assets/consoles/$SYS.png"
  if curl -fsSL -o "$DEST" "$URL" 2>/dev/null; then
    echo "  [OK] $SYS.png"
  else
    echo "  [skip] $SYS console art"
    rm -f "$DEST"
  fi
done
echo ""

echo "=== 완료! 에셋이 $THEME_DIR/_assets/ 에 저장되었습니다. ==="
echo ""
echo "다음 단계:"
echo "  1. Inter 폰트가 없으면 _assets/fonts/ 에 수동으로 복사하세요."
echo "  2. EmulationStation에서 테마를 선택하면 바로 사용 가능합니다."
