################################################################################
#
# bundled-fonts - 번들 한글 폰트 (다운로드본 설치)
#
# board/odroidc5/fetch-fonts.sh가 공식 배포처에서 받아 sha256 검증 후
# board/odroidc5/blobs/fonts/에 준비해둔 TTF를 타깃 경로에 설치한다.
# (mali-ddk와 동일한 "빌드 전 fetch 스크립트 + 패키지 설치" 패턴)
#
################################################################################

BUNDLED_FONTS_VERSION = 1.0
BUNDLED_FONTS_LICENSE = OFL-1.1 (나눔/D2Coding/Pretendard)
# 자체 파일 복사이므로 Buildroot 자동 다운로드 비활성화
BUNDLED_FONTS_SOURCE =

# retroarch-assets가 기본 ozone 폰트를, emulationstation이 resources/를
# 먼저 설치한 뒤에 우리 폰트로 덮어써야 함 - 예전 rootfs-overlay 방식은
# overlay가 항상 마지막에 적용돼서 자연히 보장됐지만, 패키지 방식에서는
# 의존성으로 순서를 강제해야 함.
BUNDLED_FONTS_DEPENDENCIES = retroarch-assets emulationstation

BUNDLED_FONTS_DIR_ = $(BR2_EXTERNAL_C5_PANGUI_PATH)/../board/odroidc5/blobs/fonts

define BUNDLED_FONTS_CHECK
	@if [ ! -f "$(BUNDLED_FONTS_DIR_)/NanumGothic.ttf" ]; then \
		echo ""; \
		echo "ERROR: bundled fonts not found!"; \
		echo "  Expected: $(BUNDLED_FONTS_DIR_)/NanumGothic.ttf"; \
		echo "  Run: bash board/odroidc5/fetch-fonts.sh"; \
		echo ""; \
		exit 1; \
	fi
endef

define BUNDLED_FONTS_INSTALL_TARGET_CMDS
	$(call BUNDLED_FONTS_CHECK)
	# RetroArch ozone 메뉴 + 한글 폴백 (나눔고딕 - RA 한글 깨짐 수정용)
	$(INSTALL) -D -m 0644 $(BUNDLED_FONTS_DIR_)/NanumGothic.ttf \
		$(TARGET_DIR)/usr/share/retroarch/ozone/fonts/regular.ttf
	$(INSTALL) -D -m 0644 $(BUNDLED_FONTS_DIR_)/NanumGothicBold.ttf \
		$(TARGET_DIR)/usr/share/retroarch/ozone/fonts/bold.ttf
	$(INSTALL) -D -m 0644 $(BUNDLED_FONTS_DIR_)/NanumGothic.ttf \
		$(TARGET_DIR)/usr/share/retroarch/pkg/korean-fallback-font.ttf
	# EmulationStation UI 폰트 (나눔바른고딕 - ES가 이 경로를 하드 참조)
	$(INSTALL) -D -m 0644 $(BUNDLED_FONTS_DIR_)/NanumBarunGothic.ttf \
		$(TARGET_DIR)/usr/bin/resources/NanumBarunGothic.ttf
	# 시스템 폰트 (터미널 고정폭 D2Coding, UI 산세리프 Pretendard)
	$(INSTALL) -D -m 0644 $(BUNDLED_FONTS_DIR_)/D2Coding-Regular.ttf \
		$(TARGET_DIR)/usr/share/fonts/truetype/d2coding/D2Coding-Regular.ttf
	$(INSTALL) -D -m 0644 $(BUNDLED_FONTS_DIR_)/Pretendard-Regular.ttf \
		$(TARGET_DIR)/usr/share/fonts/truetype/pretendard/Pretendard-Regular.ttf
endef

$(eval $(generic-package))
