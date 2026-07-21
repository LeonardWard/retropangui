################################################################################
#
# libretro-core-nestopia - NES/Famicom
#
# 2026-07-14: libretro-cores.mk에서 분리(todo-20260712-libretro-cores-package-split).
# 빌드 커맨드는 원본과 동일.
#
################################################################################

LIBRETRO_CORE_NESTOPIA_SOURCE =
LIBRETRO_CORE_NESTOPIA_DEPENDENCIES = mesa3d
LIBRETRO_CORE_NESTOPIA_LICENSE = GPL-2.0

LIBRETRO_CORE_NESTOPIA_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_NESTOPIA_BUILD_CMDS
	test -d $(@D)/nestopia/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_NESTOPIA_SITE) $(@D)/nestopia
	git -C $(@D)/nestopia checkout $(LIBRETRO_CORE_NESTOPIA_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/nestopia/libretro \
		$(LIBRETRO_CORE_NESTOPIA_CROSS_OPTS) \
		platform=unix
endef

define LIBRETRO_CORE_NESTOPIA_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-nestopia
	$(INSTALL) -m 0644 $(@D)/nestopia/libretro/nestopia_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-nestopia/
	echo "nestopia_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-nestopia/.installed_so_name
endef

$(eval $(generic-package))
