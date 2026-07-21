################################################################################
#
# libretro-core-beetle-psx-hw - PlayStation 1 (Vulkan HW renderer, desktop OpenGL 제외)
# HAVE_VULKAN=1 단독 사용: Vulkan만 활성화, HAVE_OPENGL은 0 유지
# Mali Valhall(r44p0)은 Vulkan을 지원하므로 HW 가속 가능
#
# 2026-07-14: libretro-cores.mk에서 분리(todo-20260712-libretro-cores-package-split).
# 빌드 커맨드는 원본과 동일.
#
################################################################################

LIBRETRO_CORE_BEETLE_PSX_HW_SOURCE =
LIBRETRO_CORE_BEETLE_PSX_HW_DEPENDENCIES = mesa3d

LIBRETRO_CORE_BEETLE_PSX_HW_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_BEETLE_PSX_HW_BUILD_CMDS
	test -d $(@D)/beetle-psx-libretro/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_BEETLE_PSX_HW_SITE) $(@D)/beetle-psx-libretro
	git -C $(@D)/beetle-psx-libretro checkout $(LIBRETRO_CORE_BEETLE_PSX_HW_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/beetle-psx-libretro \
		$(LIBRETRO_CORE_BEETLE_PSX_HW_CROSS_OPTS) \
		HAVE_VULKAN=1 \
		HAVE_OPENGL=0 \
		LINK_STATIC_LIBCPLUSPLUS=0 \
		platform=$(LIBRETRO_CORE_BEETLE_PSX_HW_PLATFORM)
endef

define LIBRETRO_CORE_BEETLE_PSX_HW_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-beetle-psx-hw
	$(INSTALL) -m 0644 $(@D)/beetle-psx-libretro/mednafen_psx_hw_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-beetle-psx-hw/
	echo "mednafen_psx_hw_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-beetle-psx-hw/.installed_so_name
endef

$(eval $(generic-package))
