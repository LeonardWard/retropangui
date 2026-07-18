################################################################################
#
# libretro-core-fbneo - FinalBurn Neo (아케이드 / CPS1-2-3 / Neo Geo / Neo Geo CD)
#
# 2026-07-19: arcade/neogeo/neogeocd 시스템 신설과 함께 추가.
# unix platform findstring 매칭이 rpi1/rpi2/rpi3/rpi4_64/rpi5_64/armv/android만
# 특별 취급하고 그 외(odroidc5 포함)는 별도 아키텍처 플래그 없이 기본 unix 빌드
# 경로를 타므로, buildroot 툴체인의 -mcpu=cortex-a55가 그대로 적용됨
# (libretro-core-yabasanshiro.mk가 겪은 "platform=unix가 x86_64 SSE를 강제"
# 문제는 FBNeo Makefile엔 해당 로직이 없어 발생하지 않음).
# HAVE_NEON은 명시적으로 켜야 함(findstring 매칭 안 되면 기본값 0).
# USE_CYCLONE(ARM32 전용 68k 어셈블리 코어)은 aarch64라 켜지 않음
# (batocera도 BR2_arm 32비트에서만 켬).
#
################################################################################

LIBRETRO_CORE_FBNEO_VERSION = 808243ba2a95061e6bd2a86829dc54b46dfded99
LIBRETRO_CORE_FBNEO_SITE = https://github.com/libretro/FBNeo
LIBRETRO_CORE_FBNEO_SOURCE =

LIBRETRO_CORE_FBNEO_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)"

define LIBRETRO_CORE_FBNEO_BUILD_CMDS
	test -d $(@D)/fbneo/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_FBNEO_SITE) $(@D)/fbneo
	git -C $(@D)/fbneo checkout $(LIBRETRO_CORE_FBNEO_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/fbneo/src/burner/libretro \
		-f Makefile \
		$(LIBRETRO_CORE_FBNEO_CROSS_OPTS) \
		platform=unix HAVE_NEON=1
endef

define LIBRETRO_CORE_FBNEO_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-fbneo
	$(INSTALL) -m 0644 $(@D)/fbneo/src/burner/libretro/fbneo_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-fbneo/
	echo "fbneo_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-fbneo/.installed_so_name
endef

$(eval $(generic-package))
