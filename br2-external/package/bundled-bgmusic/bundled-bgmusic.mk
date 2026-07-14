################################################################################
#
# bundled-bgmusic - 번들 배경음악(MIDI)
#
# MIDI 재생은 디코딩이 아니라 신디사이저 합성이 필요 — VLC fluidsynth
# 플러그인(BR2_PACKAGE_FLUIDSYNTH) + 사운드폰트(sf2) 조합으로 동작.
# 사운드폰트 자체는 Buildroot 공식 fluid-soundfont 패키지(FluidR3_GM.sf2,
# MIT, defconfig에서 별도 활성화)가 /usr/share/soundfonts/에 설치 -
# 여기서는 .mid 파일만 다룬다. 2026-07-14: 기존에 archive.org에서 직접
# 받던 MT32.sf2(라이선스 불명확)는 폐기하고 fluid-soundfont로 교체.
# .mid 파일은 첫 부팅 시 S61share가 /retropangui/share/bios/music/로 복사.
#
################################################################################

BUNDLED_BGMUSIC_VERSION = 1.0
BUNDLED_BGMUSIC_LICENSE = Various
BUNDLED_BGMUSIC_SOURCE =
BUNDLED_BGMUSIC_DEPENDENCIES = fluid-soundfont

define BUNDLED_BGMUSIC_INSTALL_TARGET_CMDS
	rm -rf $(TARGET_DIR)/usr/share/retropangui/bundled-bgmusic
	mkdir -p $(TARGET_DIR)/usr/share/retropangui/bundled-bgmusic
	$(INSTALL) -m 0644 $(BUNDLED_BGMUSIC_PKGDIR)/*.mid \
		$(TARGET_DIR)/usr/share/retropangui/bundled-bgmusic/
endef

$(eval $(generic-package))
