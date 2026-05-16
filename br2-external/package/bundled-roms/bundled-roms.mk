################################################################################
#
# bundled-roms - Freely licensed homebrew games bundled with the image
#
################################################################################

BUNDLED_ROMS_VERSION = 1.0
BUNDLED_ROMS_LICENSE = GPL-3.0
# 자체 wget으로 다운로드하므로 Buildroot 자동 소스 다운로드 비활성화
BUNDLED_ROMS_SOURCE =

# NES: Nova the Squirrel - full platformer (GPL-3.0)
NOVA_URL = https://github.com/NovaSquirrel/NovaTheSquirrel/releases/download/v1.0.6a/nova.nes
# NES: Thwaite - missile command style arcade (GPL-3.0)
THWAITE_URL = https://github.com/pinobatch/thwaite-nes/releases/download/v0.04/thwaite.nes
# NES: 2048 - puzzle game (open source)
NES2048_URL = https://raw.githubusercontent.com/mmuszkow/2048-nes/master/2048.nes
# SNES: Super-Apocalux - action game (GPL-3.0)
APOCALUX_URL = https://github.com/DanielTheSilly/Super-Apocalux/releases/download/V1.0b/Super-Apocalux_V1.0b.smc

BUNDLED_ROMS_TARGET_DIR = $(TARGET_DIR)/usr/share/retropangui/bundled-roms

define BUNDLED_ROMS_BUILD_CMDS
	mkdir -p $(@D)/nes $(@D)/snes
	$(if $(wildcard $(@D)/nes/nova.nes),,\
		wget -q -O $(@D)/nes/nova.nes $(NOVA_URL))
	$(if $(wildcard $(@D)/nes/thwaite.nes),,\
		wget -q -O $(@D)/nes/thwaite.nes $(THWAITE_URL))
	$(if $(wildcard $(@D)/nes/2048.nes),,\
		wget -q -O $(@D)/nes/2048.nes $(NES2048_URL))
	$(if $(wildcard $(@D)/snes/Super-Apocalux.smc),,\
		wget -q -O $(@D)/snes/Super-Apocalux.smc $(APOCALUX_URL))
endef

define BUNDLED_ROMS_INSTALL_TARGET_CMDS
	mkdir -p $(BUNDLED_ROMS_TARGET_DIR)/nes $(BUNDLED_ROMS_TARGET_DIR)/snes
	cp $(@D)/nes/*.nes $(BUNDLED_ROMS_TARGET_DIR)/nes/
	cp $(@D)/snes/*.smc $(BUNDLED_ROMS_TARGET_DIR)/snes/
endef

$(eval $(generic-package))
