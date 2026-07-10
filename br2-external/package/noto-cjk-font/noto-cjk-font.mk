################################################################################
#
# noto-cjk-font
#
# CJK 한자 폴백 폰트 파일 하나만 받아서 ES가 이미 기대하고 있는 경로에
# 설치. NotoSansCJK-Regular.ttc(SC/TC/JP/KR/HK 통합 OTC, ~18.6MB)를
# notofonts/noto-cjk 저장소에서 이 파일을 마지막으로 수정한 커밋에
# 고정해서 받음 - 저장소 전체(수백MB)를 클론할 필요 없음.
#
################################################################################

NOTO_CJK_FONT_VERSION = 165c01b46ea533872e002e0785ff17e44f6d97d8
NOTO_CJK_FONT_SITE = https://raw.githubusercontent.com/notofonts/noto-cjk/$(NOTO_CJK_FONT_VERSION)/Sans/OTC
NOTO_CJK_FONT_SOURCE = NotoSansCJK-Regular.ttc
NOTO_CJK_FONT_LICENSE = OFL-1.1
NOTO_CJK_FONT_TARGET_DIR = $(TARGET_DIR)/usr/share/fonts/opentype/noto

# 일반 아카이브가 아니라 폰트 파일 하나 - 그대로 복사만
define NOTO_CJK_FONT_EXTRACT_CMDS
	cp $(NOTO_CJK_FONT_DL_DIR)/$(NOTO_CJK_FONT_SOURCE) $(@D)/
endef

define NOTO_CJK_FONT_INSTALL_TARGET_CMDS
	mkdir -p $(NOTO_CJK_FONT_TARGET_DIR)
	$(INSTALL) -m 0644 -D $(@D)/$(NOTO_CJK_FONT_SOURCE) \
		$(NOTO_CJK_FONT_TARGET_DIR)/$(NOTO_CJK_FONT_SOURCE)
endef

$(eval $(generic-package))
