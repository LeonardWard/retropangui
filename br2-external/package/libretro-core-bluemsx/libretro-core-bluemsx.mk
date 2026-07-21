################################################################################
#
# libretro-core-bluemsx - MSX / MSX2 / MSX2+ / MSX turbo R
#
# 2026-07-14: libretro-cores.mk에서 분리(todo-20260712-libretro-cores-package-split).
# 빌드 커맨드는 원본과 동일.
#
################################################################################

LIBRETRO_CORE_BLUEMSX_SOURCE =
LIBRETRO_CORE_BLUEMSX_DEPENDENCIES = mesa3d

LIBRETRO_CORE_BLUEMSX_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_BLUEMSX_BUILD_CMDS
	test -d $(@D)/bluemsx-libretro/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_BLUEMSX_SITE) $(@D)/bluemsx-libretro
	git -C $(@D)/bluemsx-libretro checkout $(LIBRETRO_CORE_BLUEMSX_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/bluemsx-libretro \
		-f Makefile.libretro \
		$(LIBRETRO_CORE_BLUEMSX_CROSS_OPTS) \
		platform=$(LIBRETRO_CORE_BLUEMSX_PLATFORM)
endef

define LIBRETRO_CORE_BLUEMSX_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-bluemsx
	$(INSTALL) -m 0644 $(@D)/bluemsx-libretro/bluemsx_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-bluemsx/
	echo "bluemsx_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-bluemsx/.installed_so_name
	mkdir -p $(TARGET_DIR)/usr/share/retropangui/bundled-bios
	cp -r $(@D)/bluemsx-libretro/system/bluemsx/Machines \
		$(TARGET_DIR)/usr/share/retropangui/bundled-bios/
	cp -r $(@D)/bluemsx-libretro/system/bluemsx/Databases \
		$(TARGET_DIR)/usr/share/retropangui/bundled-bios/
endef

$(eval $(generic-package))
