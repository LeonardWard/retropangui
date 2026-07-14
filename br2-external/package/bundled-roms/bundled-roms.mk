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
# PSX: 240p Test Suite (filipalac, GPL-2.0) - EMU 버전 (.bin/.cue)
PS240P_URL   = https://github.com/filipalac/240pTestSuite-PS1/releases/download/19122020/240pTestSuitePS1-EMU.zip

# NES 번들 목록 (retrobrews + 개별 다운로드에서 선별)
BUNDLED_NES_ROMS = 2048.nes croom.nes driar.nes fff.nes indivisibleonnes.nes lala.nes owlia.nes thewit.nes

# SNES 번들 목록 (retrobrews에서 선별)
BUNDLED_SNES_ROMS = jetpilotrising.sfc saf.smc superbossgaiden.sfc

BUNDLED_ROMS_TARGET_DIR = $(TARGET_DIR)/usr/share/retropangui/bundled-roms

# 2026-07-15: 박스아트/스크린샷 URL 매핑 파일 - 저장소에 이미지 바이너리를
# 커밋하지 않고 원 배포처에서 빌드 시점에 받아온다(todo-20260714-bundled-
# game-curation 사용자 지시 - "임시로" 코드 다운로드 방식, 이미지 검토 후
# URL이 교체될 수 있음). "롬파일스템 URL" 한 줄씩(공백 구분).
BUNDLED_ROMS_IMAGE_URLS_FILE = $(BUNDLED_ROMS_PKGDIR)/image-urls.txt

# 폴더명은 롬 파일명이 아니라 게임 정식 명칭을 쓴다(사용자 지시, 2026-07-15).
# "롬파일스템|정식 폴더명" 한 줄씩(공백이 들어간 이름이 많아 | 구분).
BUNDLED_ROMS_FOLDER_NAMES_FILE = $(BUNDLED_ROMS_PKGDIR)/folder-names.txt

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

	# 240p Test Suite PSX EMU 버전 (캐시 있으면 스킵)
	if [ ! -f $(@D)/psx/240pTestSuitePS1-EMU.bin ]; then \
		echo "[bundled-roms] 240p Test Suite PS1 다운로드 중..."; \
		wget -q -O $(@D)/240pTestSuitePS1-EMU.zip $(PS240P_URL) && \
		unzip -q -o $(@D)/240pTestSuitePS1-EMU.zip -d $(@D)/psx && \
		rm -f $(@D)/240pTestSuitePS1-EMU.zip; \
	fi
endef

define BUNDLED_ROMS_INSTALL_TARGET_CMDS
	# BUNDLED_NES_ROMS/BUNDLED_SNES_ROMS 목록이 줄어들어도 예전 설치본이 남지 않도록
	# 매번 깨끗이 지우고 다시 채운다 (cp만 하면 목록에서 뺀 게임이 계속 남는 문제 방지)
	rm -rf $(BUNDLED_ROMS_TARGET_DIR)
	mkdir -p $(BUNDLED_ROMS_TARGET_DIR)/nes $(BUNDLED_ROMS_TARGET_DIR)/snes $(BUNDLED_ROMS_TARGET_DIR)/psx
	# 2026-07-15: 게임별 폴더로 배치(todo-20260714-bundled-game-curation) -
	# 큐레이션 단계에서 같은 폴더에 gamelist.xml/이미지를 동봉하기 위한 준비.
	# 폴더명은 롬 파일명이 아니라 게임 정식 명칭(folder-names.txt 매핑, 사용자 지시).
	for rom in $(BUNDLED_NES_ROMS); do \
		stem="$${rom%.*}"; \
		dir=$$(awk -F'|' -v k="$$stem" '$$1==k{print $$2}' $(BUNDLED_ROMS_FOLDER_NAMES_FILE)); \
		[ -n "$$dir" ] || dir="$$stem"; \
		mkdir -p "$(BUNDLED_ROMS_TARGET_DIR)/nes/$$dir"; \
		cp $(@D)/nes/$$rom "$(BUNDLED_ROMS_TARGET_DIR)/nes/$$dir/" 2>/dev/null || true; \
		imgurl=$$(awk -v k="$$stem" '$$1==k{print $$2}' $(BUNDLED_ROMS_IMAGE_URLS_FILE)); \
		[ -n "$$imgurl" ] && wget -q -O "$(BUNDLED_ROMS_TARGET_DIR)/nes/$$dir/image.png" "$$imgurl"; \
	done
	for rom in $(BUNDLED_SNES_ROMS); do \
		stem="$${rom%.*}"; \
		dir=$$(awk -F'|' -v k="$$stem" '$$1==k{print $$2}' $(BUNDLED_ROMS_FOLDER_NAMES_FILE)); \
		[ -n "$$dir" ] || dir="$$stem"; \
		mkdir -p "$(BUNDLED_ROMS_TARGET_DIR)/snes/$$dir"; \
		cp $(@D)/snes/$$rom "$(BUNDLED_ROMS_TARGET_DIR)/snes/$$dir/" 2>/dev/null || true; \
		imgurl=$$(awk -v k="$$stem" '$$1==k{print $$2}' $(BUNDLED_ROMS_IMAGE_URLS_FILE)); \
		[ -n "$$imgurl" ] && wget -q -O "$(BUNDLED_ROMS_TARGET_DIR)/snes/$$dir/image.png" "$$imgurl"; \
	done
	mkdir -p "$(BUNDLED_ROMS_TARGET_DIR)/psx/240p Test Suite"
	cp $(@D)/psx/*.bin "$(BUNDLED_ROMS_TARGET_DIR)/psx/240p Test Suite/" 2>/dev/null || true
	cp $(@D)/psx/*.cue "$(BUNDLED_ROMS_TARGET_DIR)/psx/240p Test Suite/" 2>/dev/null || true
	# 2026-07-15: 큐레이션한 gamelist.xml(전체 필드) 저장소에서 그대로 설치.
	# 이미지는 위에서 원 배포처 다운로드로 채워짐(검토 후 URL이 바뀔 수 있음).
	$(INSTALL) -m 0644 $(BUNDLED_ROMS_PKGDIR)/gamelist-nes.xml "$(BUNDLED_ROMS_TARGET_DIR)/nes/gamelist.xml"
	$(INSTALL) -m 0644 $(BUNDLED_ROMS_PKGDIR)/gamelist-snes.xml "$(BUNDLED_ROMS_TARGET_DIR)/snes/gamelist.xml"
	$(INSTALL) -m 0644 $(BUNDLED_ROMS_PKGDIR)/gamelist-psx.xml "$(BUNDLED_ROMS_TARGET_DIR)/psx/gamelist.xml"
endef

$(eval $(generic-package))
