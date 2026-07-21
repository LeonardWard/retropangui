################################################################################
#
# bundled-roms - Freely licensed homebrew games bundled with the image
#
# NES : retrobrews/nes-games (~83종) + 2048 (retrobrews 미포함)
# SNES: retrobrews/snes-games (~14종) + Super-Apocalux (retrobrews 미포함)
# PSX : 240p Test Suite (filipalac fork, GPL-2.0) - EMU 버전
# Mega Drive/MSX1/MSX2/ScummVM: Recalbox romfs2 (CC BY-NC-SA/GPL/공식 freeware)
#
# 2026-07-21: Mega Drive/MSX1/MSX2/ScummVM을 S61share의 download_extra_roms()
# (첫 부팅 시 네트워크 다운로드)에서 이 패키지로 이전 - nes/snes/psx와 동일하게
# 빌드 시점에 받아서 squashfs에 굽는 방식으로 통일(사용자 지시,
# todo-20260704-es-multi-path-roms.html). URL은 download_extra_roms()가 쓰던
# 것을 그대로 재사용. 게임별 폴더명/gamelist.xml은 board/odroidc5/rootfs-overlay/
# usr/share/retropangui/bundled-roms/{sys}/에 이미 있는 걸 그대로 씀(이 패키지는
# 실제 ROM 파일과 이미지만 그 폴더 구조에 맞춰 채워넣음) - rootfs-overlay가
# 패키지 설치 이후에 합쳐지므로 gamelist.xml은 항상 rootfs-overlay 쪽이 최종본.
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

# Mega Drive/MSX1/MSX2/ScummVM - Recalbox romfs2 raw (기존 download_extra_roms()와 동일 출처)
RECALBOX_ROMFS_BASE = https://gitlab.com/recalbox/recalbox/-/raw/master/package/recalbox-romfs2/systems

# $(call bundled-roms-dl,상대경로(=(@D) 기준),RECALBOX_ROMFS_BASE 이후 경로)
# 이미 받아둔 파일은 다시 안 받음(증분 빌드 캐시).
define bundled-roms-dl
	test -f "$(@D)/$(1)" || wget -q -O "$(@D)/$(1)" "$(RECALBOX_ROMFS_BASE)/$(2)"
endef

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

	# Mega Drive/MSX1/MSX2/ScummVM - 게임별 폴더 그대로 받아서 $(@D)/extra/에
	# 최종 설치 구조와 동일하게 쌓음(캐시 있으면 파일별로 스킵). URL은
	# download_extra_roms()(구 S61share, 2026-06-27)가 쓰던 것과 동일.
	mkdir -p "$(@D)/extra/megadrive/Yazzie (Retrosouls)" \
	         "$(@D)/extra/megadrive/Gluf (Retrosouls)" \
	         "$(@D)/extra/megadrive/Old Towers (Retrosouls)" \
	         "$(@D)/extra/megadrive/Misplaced (Retrosouls)" \
	         "$(@D)/extra/msx1/xracing" "$(@D)/extra/msx1/xspelunker-en" "$(@D)/extra/msx1/Yazzie" \
	         "$(@D)/extra/msx2/Brunilda [v1.1] (Retroworks)" \
	         "$(@D)/extra/msx2/The Sword of Ianna (Retroworks)" \
	         "$(@D)/extra/scummvm/Beneath a Steel Sky (English).scummvm" \
	         "$(@D)/extra/scummvm/Flight of the Amazon Queen (English).scummvm" \
	         "$(@D)/extra/scummvm/Soltys (English).scummvm" \
	         "$(@D)/extra/scummvm/Lure of the Tempress (English).scummvm"

	$(call bundled-roms-dl,extra/megadrive/Yazzie (Retrosouls)/Yazzie (Retrosouls).bin,megadrive/init/roms/Yazzie%20(Retrosouls).bin)
	$(call bundled-roms-dl,extra/megadrive/Yazzie (Retrosouls)/image.png,megadrive/init/roms/media/images/Yazzie%20(Retrosouls).png)
	$(call bundled-roms-dl,extra/megadrive/Gluf (Retrosouls)/Gluf (Retrosouls).bin,megadrive/init/roms/Gluf%20(Retrosouls).bin)
	$(call bundled-roms-dl,extra/megadrive/Gluf (Retrosouls)/image.png,megadrive/init/roms/media/images/Gluf%20(Retrosouls).png)
	$(call bundled-roms-dl,extra/megadrive/Old Towers (Retrosouls)/Old Towers (Retrosouls).bin,megadrive/init/roms/Old%20Towers%20(Retrosouls).bin)
	$(call bundled-roms-dl,extra/megadrive/Old Towers (Retrosouls)/image.png,megadrive/init/roms/media/images/Old%20Towers%20(Retrosouls).png)
	$(call bundled-roms-dl,extra/megadrive/Misplaced (Retrosouls)/Misplaced (Retrosouls).bin,megadrive/init/roms/Misplaced%20(Retrosouls).bin)
	$(call bundled-roms-dl,extra/megadrive/Misplaced (Retrosouls)/image.png,megadrive/init/roms/media/images/Misplaced%20(Retrosouls).png)

	$(call bundled-roms-dl,extra/msx1/xracing/xracing.rom,msx1/init/roms/xracing.rom)
	$(call bundled-roms-dl,extra/msx1/xracing/image.png,msx1/init/roms/media/images/xracing.png)
	$(call bundled-roms-dl,extra/msx1/xspelunker-en/xspelunker-en.rom,msx1/init/roms/xspelunker-en.rom)
	$(call bundled-roms-dl,extra/msx1/xspelunker-en/image.png,msx1/init/roms/media/images/xspelunker-en.png)
	$(call bundled-roms-dl,extra/msx1/Yazzie/Yazzie.rom,msx1/init/roms/Yazzie.rom)
	$(call bundled-roms-dl,extra/msx1/Yazzie/image.png,msx1/init/roms/media/images/Yazzie.png)

	$(call bundled-roms-dl,extra/msx2/Brunilda [v1.1] (Retroworks)/Brunilda [v1.1] (Retroworks).rom,msx2/init/roms/Brunilda%20%5Bv1.1%5D%20(Retroworks).rom)
	$(call bundled-roms-dl,extra/msx2/Brunilda [v1.1] (Retroworks)/image.png,msx2/init/roms/media/images/Brunilda%20%5Bv1.1%5D%20(Retroworks).png)
	$(call bundled-roms-dl,extra/msx2/The Sword of Ianna (Retroworks)/The Sword of Ianna (Retroworks).rom,msx2/init/roms/The%20Sword%20of%20Ianna%20(Retroworks).rom)
	$(call bundled-roms-dl,extra/msx2/The Sword of Ianna (Retroworks)/image.png,msx2/init/roms/media/images/The%20Sword%20of%20Ianna%20(Retroworks).png)

	$(call bundled-roms-dl,extra/scummvm/Beneath a Steel Sky (English).scummvm/sky.dnr,scummvm/init/roms/Beneath%20a%20Steel%20Sky%20(English).scummvm/sky.dnr)
	$(call bundled-roms-dl,extra/scummvm/Beneath a Steel Sky (English).scummvm/sky.dsk,scummvm/init/roms/Beneath%20a%20Steel%20Sky%20(English).scummvm/sky.dsk)
	$(call bundled-roms-dl,extra/scummvm/Beneath a Steel Sky (English).scummvm/image.png,scummvm/init/roms/media/images/Beneath%20a%20Steel%20Sky%20(English).png)
	$(call bundled-roms-dl,extra/scummvm/Flight of the Amazon Queen (English).scummvm/queen.1,scummvm/init/roms/Flight%20of%20the%20Amazon%20Queen%20(English).scummvm/queen.1)
	$(call bundled-roms-dl,extra/scummvm/Flight of the Amazon Queen (English).scummvm/image.png,scummvm/init/roms/media/images/Flight%20of%20the%20Amazon%20Queen%20(Fran%C3%A7ais).png)
	$(call bundled-roms-dl,extra/scummvm/Soltys (English).scummvm/vol.cat,scummvm/init/roms/Soltys%20(English).scummvm/vol.cat)
	$(call bundled-roms-dl,extra/scummvm/Soltys (English).scummvm/vol.dat,scummvm/init/roms/Soltys%20(English).scummvm/vol.dat)
	$(call bundled-roms-dl,extra/scummvm/Soltys (English).scummvm/image.png,scummvm/init/roms/media/images/Soltys%20(English).png)
	$(call bundled-roms-dl,extra/scummvm/Lure of the Tempress (English).scummvm/Disk1.vga,scummvm/init/roms/Lure%20of%20the%20Tempress%20(English).scummvm/Disk1.vga)
	$(call bundled-roms-dl,extra/scummvm/Lure of the Tempress (English).scummvm/Disk2.vga,scummvm/init/roms/Lure%20of%20the%20Tempress%20(English).scummvm/Disk2.vga)
	$(call bundled-roms-dl,extra/scummvm/Lure of the Tempress (English).scummvm/Disk3.vga,scummvm/init/roms/Lure%20of%20the%20Tempress%20(English).scummvm/Disk3.vga)
	$(call bundled-roms-dl,extra/scummvm/Lure of the Tempress (English).scummvm/Disk4.vga,scummvm/init/roms/Lure%20of%20the%20Tempress%20(English).scummvm/Disk4.vga)
	$(call bundled-roms-dl,extra/scummvm/Lure of the Tempress (English).scummvm/Lure.exe,scummvm/init/roms/Lure%20of%20the%20Tempress%20(English).scummvm/Lure.exe)
	$(call bundled-roms-dl,extra/scummvm/Lure of the Tempress (English).scummvm/image.png,scummvm/init/roms/media/images/Lure%20of%20the%20Tempress%20(Fran%C3%A7ais).png)
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

	# 2026-07-21: Mega Drive/MSX1/MSX2/ScummVM 실물 파일 설치 - 폴더 구조는
	# $(@D)/extra/{sys}/에 이미 최종 형태로 받아둔 걸 그대로 복사. gamelist.xml은
	# 여기서 안 씀 - board/odroidc5/rootfs-overlay/usr/share/retropangui/
	# bundled-roms/{sys}/gamelist.xml(이 패키지 설치 "이후"에 합쳐지는
	# rootfs-overlay 쪽)이 최종본이라 중복 설치할 필요 없음.
	mkdir -p $(BUNDLED_ROMS_TARGET_DIR)/megadrive $(BUNDLED_ROMS_TARGET_DIR)/msx1 \
	         $(BUNDLED_ROMS_TARGET_DIR)/msx2 $(BUNDLED_ROMS_TARGET_DIR)/scummvm
	cp -r "$(@D)/extra/megadrive/." "$(BUNDLED_ROMS_TARGET_DIR)/megadrive/"
	cp -r "$(@D)/extra/msx1/." "$(BUNDLED_ROMS_TARGET_DIR)/msx1/"
	cp -r "$(@D)/extra/msx2/." "$(BUNDLED_ROMS_TARGET_DIR)/msx2/"
	cp -r "$(@D)/extra/scummvm/." "$(BUNDLED_ROMS_TARGET_DIR)/scummvm/"
endef

$(eval $(generic-package))
