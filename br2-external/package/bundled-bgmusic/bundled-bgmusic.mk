################################################################################
#
# bundled-bgmusic - 번들 배경음악(MIDI) + MT-32 사운드폰트
#
# MIDI 재생은 디코딩이 아니라 신디사이저 합성이 필요 — VLC fluidsynth
# 플러그인(BR2_PACKAGE_FLUIDSYNTH) + 사운드폰트(sf2) 조합으로 동작.
# MT32.sf2(약 7.2MB)는 archive.org에서 빌드 시 다운로드 (sha256 검증).
# .mid 파일은 첫 부팅 시 S61share가 /retropangui/share/music/로 복사.
#
################################################################################

BUNDLED_BGMUSIC_VERSION = 1.0
BUNDLED_BGMUSIC_LICENSE = Various
# 자체 wget으로 다운로드하므로 Buildroot 자동 소스 다운로드 비활성화
BUNDLED_BGMUSIC_SOURCE =

MT32_SF2_URL = https://archive.org/download/free-soundfonts-sf2-2019-04/MT32.sf2
MT32_SF2_SHA256 = 94b3cee6cff74f83970f73733a2295d20aa0ec230bc6c2c06f17cdeb0bc4f84c

define BUNDLED_BGMUSIC_BUILD_CMDS
	if [ ! -f $(@D)/MT32.sf2 ]; then \
		echo "[bundled-bgmusic] MT32.sf2 다운로드 중..."; \
		wget -q -O $(@D)/MT32.sf2 $(MT32_SF2_URL); \
	fi
	echo "$(MT32_SF2_SHA256)  $(@D)/MT32.sf2" | sha256sum -c -
endef

define BUNDLED_BGMUSIC_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/soundfonts
	$(INSTALL) -m 0644 $(@D)/MT32.sf2 $(TARGET_DIR)/usr/share/soundfonts/MT32.sf2
	mkdir -p $(TARGET_DIR)/usr/share/retropangui/bundled-bgmusic
	$(INSTALL) -m 0644 $(BUNDLED_BGMUSIC_PKGDIR)/*.mid \
		$(TARGET_DIR)/usr/share/retropangui/bundled-bgmusic/
endef

$(eval $(generic-package))
