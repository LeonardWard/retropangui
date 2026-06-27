################################################################################
#
# libretro-cores - NES, SNES, PSX, MD, DOS, ScummVM libretro cores for RetroArch
#
# 버전 관리:
#   fceumm          : 커밋 c0c52ad0 (2026-06, libretro/libretro-fceumm, FDS BIOS 불필요)
#   nestopia        : 커밋 b0fd87dd (2024-01, libretro/nestopia, 별도 릴리즈 태그 없음)
#   snes9x          : 커밋 e755ae51 (2025-04, libretro/snes9x, 별도 릴리즈 태그 없음)
#   pcsx_rearmed    : 릴리즈 태그 r26l (libretro/pcsx_rearmed)
#   beetle_psx_hw   : 커밋 d460f834 (2026-06, libretro/beetle-psx-libretro, Vulkan HW 전용 — GL 제외)
#   picodrive       : 커밋 f0d4a011 (2026-06, libretro/picodrive, 메가드라이브/32X/MCD)
#   bluemsx         : 커밋 b76f2795 (2026-06, libretro/bluemsx-libretro, MSX/MSX2/MSX2+/turboR)
#   dosbox_pure     : 커밋 f587236b (2025-04, schellingb/dosbox-pure, 별도 릴리즈 태그 없음)
#   scummvm         : 릴리즈 태그 libretro-v3.1.0.1 (libretro/scummvm)
#
# 빌드 방식:
#   libretro 코어 Makefile은 크로스컴파일러 툴체인만 받고
#   CFLAGS/-fPIC/LD 등은 자체적으로 처리하도록 설계되어 있음.
#   TARGET_CONFIGURE_OPTS는 CFLAGS/CXXFLAGS/LD를 커맨드라인 변수로
#   넘겨 Makefile 내부 설정을 덮어쓰므로 사용하지 않음.
#   대신 크로스컴파일러 변수만 전달하는 LIBRETRO_CROSS_OPTS 사용.
#
################################################################################

LIBRETRO_CORES_VERSION = 1.0
LIBRETRO_CORES_LICENSE = GPL-2.0 (nestopia, snes9x, pcsx_rearmed, dosbox_pure, scummvm)
# 자체 git clone으로 다운로드하므로 Buildroot 자동 소스 다운로드 비활성화
LIBRETRO_CORES_SOURCE =

CORES_INSTALL_DIR = $(TARGET_DIR)/opt/retropangui/libretrocores

# libretro 코어용 크로스컴파일 변수 (툴체인만, CFLAGS/CXXFLAGS/LD 제외)
LIBRETRO_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

################################################################################
# fceumm - NES/Famicom/FDS (BIOS 불필요, FDS 내장 에뮬레이션 지원)
################################################################################

FCEUMM_SITE = https://github.com/libretro/libretro-fceumm
FCEUMM_VERSION = c0c52ad0eb36cdbfc66e9bdb72efc83103e85e22

define LIBRETRO_CORES_BUILD_FCEUMM
	test -d $(@D)/libretro-fceumm/.git || \
		git clone --filter=blob:none $(FCEUMM_SITE) $(@D)/libretro-fceumm
	git -C $(@D)/libretro-fceumm checkout $(FCEUMM_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/libretro-fceumm \
		-f Makefile.libretro \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix
endef

################################################################################
# nestopia - NES/Famicom
################################################################################

NESTOPIA_SITE = https://github.com/libretro/nestopia
NESTOPIA_VERSION = b0fd87dd07e3c52903435d302b04e5e97796f127

define LIBRETRO_CORES_BUILD_NESTOPIA
	test -d $(@D)/nestopia/.git || \
		git clone --filter=blob:none $(NESTOPIA_SITE) $(@D)/nestopia
	git -C $(@D)/nestopia checkout $(NESTOPIA_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/nestopia/libretro \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix
endef

################################################################################
# snes9x - SNES
################################################################################

SNES9X_SITE = https://github.com/libretro/snes9x
SNES9X_VERSION = e755ae51b61f49e4ac48bdeaa16e3c72e70db0e5

define LIBRETRO_CORES_BUILD_SNES9X
	test -d $(@D)/snes9x/.git || \
		git clone --filter=blob:none $(SNES9X_SITE) $(@D)/snes9x
	git -C $(@D)/snes9x checkout $(SNES9X_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/snes9x/libretro \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix
endef

################################################################################
# pcsx_rearmed - PlayStation 1
################################################################################

PCSX_SITE = https://github.com/libretro/pcsx_rearmed
PCSX_VERSION = r26l

define LIBRETRO_CORES_BUILD_PCSX
	test -d $(@D)/pcsx_rearmed/.git || \
		git clone --filter=blob:none --branch $(PCSX_VERSION) $(PCSX_SITE) $(@D)/pcsx_rearmed
	git -C $(@D)/pcsx_rearmed checkout $(PCSX_VERSION)
	git -C $(@D)/pcsx_rearmed submodule update --init
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/pcsx_rearmed \
		-f Makefile.libretro \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix
endef

################################################################################
# beetle-psx-hw - PlayStation 1 (Vulkan HW renderer, desktop OpenGL 제외)
# HAVE_VULKAN=1 단독 사용: Vulkan만 활성화, HAVE_OPENGL은 0 유지
# Mali Valhall(r44p0)은 Vulkan을 지원하므로 HW 가속 가능
################################################################################

BEETLE_PSX_HW_SITE = https://github.com/libretro/beetle-psx-libretro
BEETLE_PSX_HW_VERSION = d460f8342060526678e7fd8222048324c2a80d86

define LIBRETRO_CORES_BUILD_BEETLE_PSX_HW
	test -d $(@D)/beetle-psx-libretro/.git || \
		git clone --filter=blob:none $(BEETLE_PSX_HW_SITE) $(@D)/beetle-psx-libretro
	git -C $(@D)/beetle-psx-libretro checkout $(BEETLE_PSX_HW_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/beetle-psx-libretro \
		$(LIBRETRO_CROSS_OPTS) \
		HAVE_VULKAN=1 \
		HAVE_OPENGL=0 \
		LINK_STATIC_LIBCPLUSPLUS=0 \
		platform=unix
endef

################################################################################
# picodrive - Sega Mega Drive / Genesis / 32X / Mega-CD
################################################################################

PICODRIVE_SITE = https://github.com/libretro/picodrive
PICODRIVE_VERSION = f0d4a0118a9733a1f10bce5a4ac772c474f9300d

define LIBRETRO_CORES_BUILD_PICODRIVE
	test -d $(@D)/picodrive/.git || \
		git clone --filter=blob:none $(PICODRIVE_SITE) $(@D)/picodrive
	git -C $(@D)/picodrive checkout $(PICODRIVE_VERSION)
	git -C $(@D)/picodrive submodule update --init
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/picodrive \
		-f Makefile.libretro \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix
endef

################################################################################
# blueMSX - MSX / MSX2 / MSX2+ / MSX turbo R
################################################################################

BLUEMSX_SITE = https://github.com/libretro/bluemsx-libretro
BLUEMSX_VERSION = b76f27959a32e18aa04c619273152178fd0cf03b

define LIBRETRO_CORES_BUILD_BLUEMSX
	test -d $(@D)/bluemsx-libretro/.git || \
		git clone --filter=blob:none $(BLUEMSX_SITE) $(@D)/bluemsx-libretro
	git -C $(@D)/bluemsx-libretro checkout $(BLUEMSX_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/bluemsx-libretro \
		-f Makefile.libretro \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix
endef

################################################################################
# dosbox-pure - DOS
################################################################################

DOSBOX_PURE_SITE = https://github.com/schellingb/dosbox-pure
DOSBOX_PURE_VERSION = f587236b2d016f4f16d672e9ce2829bdf507bf9b

define LIBRETRO_CORES_BUILD_DOSBOX_PURE
	test -d $(@D)/dosbox-pure/.git || \
		git clone --filter=blob:none $(DOSBOX_PURE_SITE) $(@D)/dosbox-pure
	git -C $(@D)/dosbox-pure checkout $(DOSBOX_PURE_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/dosbox-pure \
		$(LIBRETRO_CROSS_OPTS) \
		platform=unix \
		CPUFLAGS="-DPAGESIZE=4096"
endef

################################################################################
# scummvm - Point-and-click adventures
################################################################################

SCUMMVM_SITE = https://github.com/libretro/scummvm
SCUMMVM_VERSION = libretro-v3.1.0.1
# configure_submodules.sh가 의존하는 두 서브레포
SCUMMVM_DEPS_PATH = $(@D)/scummvm/backends/platform/libretro/deps
LIBRETRO_DEPS_URL    = https://github.com/libretro/libretro-deps
LIBRETRO_DEPS_COMMIT = 7e6e34f0319f4c7448d72f0e949e76265ccf55a1
LIBRETRO_COMMON_URL    = https://github.com/libretro/libretro-common
LIBRETRO_COMMON_COMMIT = 70ed90c42ddea828f53dd1b984c6443ddb39dbd6

define LIBRETRO_CORES_BUILD_SCUMMVM
	test -d $(@D)/scummvm/.git || \
		git clone --filter=blob:none $(SCUMMVM_SITE) $(@D)/scummvm
	git -C $(@D)/scummvm checkout $(SCUMMVM_VERSION)
	mkdir -p $(SCUMMVM_DEPS_PATH)
	# libretro-deps: configure_submodules.sh는 commit hash fetch로 실패하므로 직접 클론
	test -f $(SCUMMVM_DEPS_PATH)/libretro-deps/Makefile || \
		(rm -rf $(SCUMMVM_DEPS_PATH)/libretro-deps && \
		 git clone --filter=blob:none $(LIBRETRO_DEPS_URL) $(SCUMMVM_DEPS_PATH)/libretro-deps && \
		 git -C $(SCUMMVM_DEPS_PATH)/libretro-deps checkout $(LIBRETRO_DEPS_COMMIT))
	# libretro-common: 동일
	test -f $(SCUMMVM_DEPS_PATH)/libretro-common/README.md || \
		(rm -rf $(SCUMMVM_DEPS_PATH)/libretro-common && \
		 git clone --filter=blob:none $(LIBRETRO_COMMON_URL) $(SCUMMVM_DEPS_PATH)/libretro-common && \
		 git -C $(SCUMMVM_DEPS_PATH)/libretro-common checkout $(LIBRETRO_COMMON_COMMIT))
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/scummvm/backends/platform/libretro \
		CC="$(TARGET_CC)" \
		CXX="$(TARGET_CXX)" \
		AR="$(TARGET_AR) cru" \
		RANLIB="$(TARGET_RANLIB)" \
		STRIP="$(TARGET_STRIP)" \
		OBJCOPY="$(TARGET_OBJCOPY)" \
		platform=unix \
		BUILD_64BIT=1
endef

################################################################################
# Build / Install
################################################################################

define LIBRETRO_CORES_BUILD_CMDS
	mkdir -p $(@D)
	$(call LIBRETRO_CORES_BUILD_FCEUMM)
	$(call LIBRETRO_CORES_BUILD_NESTOPIA)
	$(call LIBRETRO_CORES_BUILD_SNES9X)
	$(call LIBRETRO_CORES_BUILD_PCSX)
	$(call LIBRETRO_CORES_BUILD_BEETLE_PSX_HW)
	$(call LIBRETRO_CORES_BUILD_PICODRIVE)
	$(call LIBRETRO_CORES_BUILD_BLUEMSX)
	$(call LIBRETRO_CORES_BUILD_DOSBOX_PURE)
	$(call LIBRETRO_CORES_BUILD_SCUMMVM)
endef

define LIBRETRO_CORES_INSTALL_TARGET_CMDS
	mkdir -p $(CORES_INSTALL_DIR)

	mkdir -p $(CORES_INSTALL_DIR)/lr-fceumm
	$(INSTALL) -m 0644 $(@D)/libretro-fceumm/fceumm_libretro.so \
		$(CORES_INSTALL_DIR)/lr-fceumm/
	echo "fceumm_libretro.so" > $(CORES_INSTALL_DIR)/lr-fceumm/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-nestopia
	$(INSTALL) -m 0644 $(@D)/nestopia/libretro/nestopia_libretro.so \
		$(CORES_INSTALL_DIR)/lr-nestopia/
	echo "nestopia_libretro.so" > $(CORES_INSTALL_DIR)/lr-nestopia/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-snes9x
	$(INSTALL) -m 0644 $(@D)/snes9x/libretro/snes9x_libretro.so \
		$(CORES_INSTALL_DIR)/lr-snes9x/
	echo "snes9x_libretro.so" > $(CORES_INSTALL_DIR)/lr-snes9x/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-pcsx-rearmed
	$(INSTALL) -m 0644 $(@D)/pcsx_rearmed/pcsx_rearmed_libretro.so \
		$(CORES_INSTALL_DIR)/lr-pcsx-rearmed/
	echo "pcsx_rearmed_libretro.so" > $(CORES_INSTALL_DIR)/lr-pcsx-rearmed/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-beetle-psx-hw
	$(INSTALL) -m 0644 $(@D)/beetle-psx-libretro/mednafen_psx_hw_libretro.so \
		$(CORES_INSTALL_DIR)/lr-beetle-psx-hw/
	echo "mednafen_psx_hw_libretro.so" > $(CORES_INSTALL_DIR)/lr-beetle-psx-hw/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-picodrive
	$(INSTALL) -m 0644 $(@D)/picodrive/picodrive_libretro.so \
		$(CORES_INSTALL_DIR)/lr-picodrive/
	echo "picodrive_libretro.so" > $(CORES_INSTALL_DIR)/lr-picodrive/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-bluemsx
	$(INSTALL) -m 0644 $(@D)/bluemsx-libretro/bluemsx_libretro.so \
		$(CORES_INSTALL_DIR)/lr-bluemsx/
	echo "bluemsx_libretro.so" > $(CORES_INSTALL_DIR)/lr-bluemsx/.installed_so_name
	cp -r $(@D)/bluemsx-libretro/system/bluemsx/Machines \
		$(TARGET_DIR)/usr/share/retropangui/bios/
	cp -r $(@D)/bluemsx-libretro/system/bluemsx/Databases \
		$(TARGET_DIR)/usr/share/retropangui/bios/

	mkdir -p $(CORES_INSTALL_DIR)/lr-dosbox-pure
	$(INSTALL) -m 0644 $(@D)/dosbox-pure/dosbox_pure_libretro.so \
		$(CORES_INSTALL_DIR)/lr-dosbox-pure/
	echo "dosbox_pure_libretro.so" > $(CORES_INSTALL_DIR)/lr-dosbox-pure/.installed_so_name

	mkdir -p $(CORES_INSTALL_DIR)/lr-scummvm
	$(INSTALL) -m 0644 $(@D)/scummvm/backends/platform/libretro/scummvm_libretro.so \
		$(CORES_INSTALL_DIR)/lr-scummvm/
	echo "scummvm_libretro.so" > $(CORES_INSTALL_DIR)/lr-scummvm/.installed_so_name
	mkdir -p $(TARGET_DIR)/usr/share/retropangui/bios/scummvm
	$(INSTALL) -m 0644 $(@D)/scummvm/gui/themes/gui-icons.dat \
		$(TARGET_DIR)/usr/share/retropangui/bios/scummvm/
	$(INSTALL) -m 0644 $(@D)/scummvm/gui/themes/scummclassic.zip \
		$(TARGET_DIR)/usr/share/retropangui/bios/scummvm/
	$(INSTALL) -m 0644 $(@D)/scummvm/gui/themes/scummmodern.zip \
		$(TARGET_DIR)/usr/share/retropangui/bios/scummvm/
endef

$(eval $(generic-package))
