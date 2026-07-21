################################################################################
#
# libretro-core-quasi88 - PC-88
#
# 2026-07-14: libretro-cores.mk에서 분리(todo-20260712-libretro-cores-package-split).
# 빌드 커맨드는 원본과 동일.
#
################################################################################

LIBRETRO_CORE_QUASI88_SOURCE =
LIBRETRO_CORE_QUASI88_DEPENDENCIES = mesa3d

LIBRETRO_CORE_QUASI88_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_QUASI88_BUILD_CMDS
	test -d $(@D)/quasi88-libretro/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_QUASI88_SITE) $(@D)/quasi88-libretro
	git -C $(@D)/quasi88-libretro checkout $(LIBRETRO_CORE_QUASI88_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/quasi88-libretro \
		$(LIBRETRO_CORE_QUASI88_CROSS_OPTS) \
		platform=unix
endef

define LIBRETRO_CORE_QUASI88_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-quasi88
	$(INSTALL) -m 0644 $(@D)/quasi88-libretro/quasi88_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-quasi88/
	echo "quasi88_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-quasi88/.installed_so_name
endef

$(eval $(generic-package))
