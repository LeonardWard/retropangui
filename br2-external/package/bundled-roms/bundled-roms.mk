################################################################################
#
# bundled-roms - Freely licensed homebrew games bundled with the image
#
# NES : retrobrews/nes-games (~83종) + 2048 (retrobrews 미포함)
# SNES: retrobrews/snes-games (~14종) + Super-Apocalux (retrobrews 미포함)
# PSX : 240p Test Suite (filipalac fork, GPL-2.0) - EMU 버전
#
################################################################################

BUNDLED_ROMS_VERSION = 1.0
BUNDLED_ROMS_LICENSE = Various (see individual game licenses)
# 자체 wget으로 다운로드하므로 Buildroot 자동 소스 다운로드 비활성화
BUNDLED_ROMS_SOURCE =

# retrobrews 컬렉션 (무료 배포 승인 홈브류 게임 모음)
# https://github.com/retrobrews/nes-games
# https://github.com/retrobrews/snes-games
RETROBREWS_NES_URL  = https://github.com/retrobrews/nes-games/archive/refs/heads/master.tar.gz
RETROBREWS_SNES_URL = https://github.com/retrobrews/snes-games/archive/refs/heads/master.tar.gz

# retrobrews에 없는 게임 (개별 다운로드)
# NES: 2048 - puzzle (open source)
NES2048_URL  = https://raw.githubusercontent.com/mmuszkow/2048-nes/master/2048.nes
# SNES: Super-Apocalux - action (GPL-3.0)
APOCALUX_URL = https://github.com/DanielTheSilly/Super-Apocalux/releases/download/V1.0b/Super-Apocalux_V1.0b.smc
# PSX: 240p Test Suite (filipalac, GPL-2.0) - EMU 버전 (.bin/.cue)
PS240P_URL   = https://github.com/filipalac/240pTestSuite-PS1/releases/download/19122020/240pTestSuitePS1-EMU.zip

BUNDLED_ROMS_TARGET_DIR = $(TARGET_DIR)/usr/share/retropangui/bundled-roms

define BUNDLED_ROMS_BUILD_CMDS
	mkdir -p $(@D)/nes $(@D)/snes $(@D)/psx

	# retrobrews NES 컬렉션 (캐시 있으면 스킵)
	if [ ! -d $(@D)/nes-games-master ]; then \
		echo "[bundled-roms] retrobrews NES 컬렉션 다운로드 중..."; \
		wget -q -O $(@D)/nes-games.tar.gz $(RETROBREWS_NES_URL) && \
		tar xzf $(@D)/nes-games.tar.gz -C $(@D) && \
		rm -f $(@D)/nes-games.tar.gz; \
	fi
	cp -n $(@D)/nes-games-master/*.nes $(@D)/nes/ 2>/dev/null || true

	# retrobrews SNES 컬렉션 (캐시 있으면 스킵)
	if [ ! -d $(@D)/snes-games-master ]; then \
		echo "[bundled-roms] retrobrews SNES 컬렉션 다운로드 중..."; \
		wget -q -O $(@D)/snes-games.tar.gz $(RETROBREWS_SNES_URL) && \
		tar xzf $(@D)/snes-games.tar.gz -C $(@D) && \
		rm -f $(@D)/snes-games.tar.gz; \
	fi
	cp -n $(@D)/snes-games-master/*.smc $(@D)/snes/ 2>/dev/null || true
	cp -n $(@D)/snes-games-master/*.sfc $(@D)/snes/ 2>/dev/null || true

	# 개별 다운로드 (retrobrews 미포함)
	test -f $(@D)/nes/2048.nes       || wget -q -O $(@D)/nes/2048.nes       $(NES2048_URL)
	test -f $(@D)/snes/Super-Apocalux.smc || wget -q -O $(@D)/snes/Super-Apocalux.smc $(APOCALUX_URL)

	# 240p Test Suite PSX EMU 버전 (캐시 있으면 스킵)
	if [ ! -f $(@D)/psx/240pTestSuitePS1-EMU.bin ]; then \
		echo "[bundled-roms] 240p Test Suite PS1 다운로드 중..."; \
		wget -q -O $(@D)/240pTestSuitePS1-EMU.zip $(PS240P_URL) && \
		unzip -q -o $(@D)/240pTestSuitePS1-EMU.zip -d $(@D)/psx && \
		rm -f $(@D)/240pTestSuitePS1-EMU.zip; \
	fi
endef

define BUNDLED_ROMS_INSTALL_TARGET_CMDS
	mkdir -p $(BUNDLED_ROMS_TARGET_DIR)/nes $(BUNDLED_ROMS_TARGET_DIR)/snes $(BUNDLED_ROMS_TARGET_DIR)/psx
	cp $(@D)/nes/*.nes   $(BUNDLED_ROMS_TARGET_DIR)/nes/
	cp $(@D)/snes/*.smc  $(BUNDLED_ROMS_TARGET_DIR)/snes/ 2>/dev/null || true
	cp $(@D)/snes/*.sfc  $(BUNDLED_ROMS_TARGET_DIR)/snes/ 2>/dev/null || true
	cp $(@D)/psx/*.bin   $(BUNDLED_ROMS_TARGET_DIR)/psx/ 2>/dev/null || true
	cp $(@D)/psx/*.cue   $(BUNDLED_ROMS_TARGET_DIR)/psx/ 2>/dev/null || true
endef

$(eval $(generic-package))
