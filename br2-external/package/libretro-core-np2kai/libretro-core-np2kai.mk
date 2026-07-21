################################################################################
#
# libretro-core-np2kai - PC-98
#
# 2026-07-14: libretro-cores.mk에서 분리(todo-20260712-libretro-cores-package-split).
# 빌드 커맨드는 원본과 동일.
#
################################################################################

include $(BR2_EXTERNAL_C5_PANGUI_PATH)/package/libretro-core-organizer.mk
LIBRETRO_CORE_NP2KAI_SOURCE =
LIBRETRO_CORE_NP2KAI_DEPENDENCIES = mesa3d

LIBRETRO_CORE_NP2KAI_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_NP2KAI_BUILD_CMDS
	test -d $(@D)/np2kai/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_NP2KAI_SITE) $(@D)/np2kai
	git -C $(@D)/np2kai checkout $(LIBRETRO_CORE_NP2KAI_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/np2kai/sdl \
		-f Makefile.libretro \
		$(LIBRETRO_CORE_NP2KAI_CROSS_OPTS) \
		platform=unix
endef

define LIBRETRO_CORE_NP2KAI_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-np2kai
	$(INSTALL) -m 0644 $(@D)/np2kai/sdl/np2kai_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-np2kai/
	echo "np2kai_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-np2kai/.installed_so_name
endef

$(eval $(generic-package))
