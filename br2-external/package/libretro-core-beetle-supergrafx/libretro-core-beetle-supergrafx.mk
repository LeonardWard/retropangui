################################################################################
#
# libretro-core-beetle-supergrafx - PC Engine SuperGrafx (Mednafen 기반, 소프트웨어 렌더링)
#
# 2026-07-16: 순수 소프트웨어 렌더러(GL 의존성 없음, 상류 Makefile 확인).
#
################################################################################

include $(BR2_EXTERNAL_C5_PANGUI_PATH)/package/libretro-core-organizer.mk
LIBRETRO_CORE_BEETLE_SUPERGRAFX_SOURCE =

LIBRETRO_CORE_BEETLE_SUPERGRAFX_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_BEETLE_SUPERGRAFX_BUILD_CMDS
	test -d $(@D)/beetle-supergrafx-libretro/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_BEETLE_SUPERGRAFX_SITE) $(@D)/beetle-supergrafx-libretro
	git -C $(@D)/beetle-supergrafx-libretro checkout $(LIBRETRO_CORE_BEETLE_SUPERGRAFX_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/beetle-supergrafx-libretro \
		$(LIBRETRO_CORE_BEETLE_SUPERGRAFX_CROSS_OPTS) \
		platform=unix
endef

define LIBRETRO_CORE_BEETLE_SUPERGRAFX_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-beetle-supergrafx
	$(INSTALL) -m 0644 $(@D)/beetle-supergrafx-libretro/mednafen_supergrafx_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-beetle-supergrafx/
	echo "mednafen_supergrafx_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-beetle-supergrafx/.installed_so_name
endef

$(eval $(generic-package))
