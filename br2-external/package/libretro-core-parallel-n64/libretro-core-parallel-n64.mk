################################################################################
#
# libretro-core-parallel-n64 - Nintendo 64 (대체 코어, GLideN64 렌더러)
#
# 2026-07-14: libretro-cores.mk에서 분리(todo-20260712-libretro-cores-package-split).
# 빌드 커맨드는 원본과 동일(mupen64plus-next와 같은 ARCH/FORCE_GLES 우회 사유).
#
# 2026-07-16: HAVE_PARALLEL=1 추가(todo-core-lr-parallel-n64) - GLideN64/Glide64(GL 경로)
# 둘 다 색상 렌더링이 깨지는 버그를 angrylion(SW 렌더러)으로 확인, 기기에 Vulkan
# 드라이버(libMaliVulkan, ICD 등록됨)가 있어 Vulkan 기반 parallel-rdp 렌더러를
# 활성화. parallel-rdp는 vulkan-headers/vulkan/volk를 자체 번들하므로 별도
# glslang 등 빌드 의존성 불필요 - vulkan-loader만 링크 시점에 필요.
#
################################################################################

LIBRETRO_CORE_PARALLEL_N64_SOURCE =
LIBRETRO_CORE_PARALLEL_N64_DEPENDENCIES = mesa3d vulkan-loader vulkan-headers

LIBRETRO_CORE_PARALLEL_N64_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_PARALLEL_N64_BUILD_CMDS
	test -d $(@D)/parallel-n64/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_PARALLEL_N64_SITE) $(@D)/parallel-n64
	git -C $(@D)/parallel-n64 checkout $(LIBRETRO_CORE_PARALLEL_N64_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/parallel-n64 \
		$(LIBRETRO_CORE_PARALLEL_N64_CROSS_OPTS) \
		platform=$(LIBRETRO_CORE_PARALLEL_N64_PLATFORM) \
		ARCH=aarch64 \
		FORCE_GLES=1 \
		HAVE_PARALLEL=1
endef

define LIBRETRO_CORE_PARALLEL_N64_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-parallel-n64
	$(INSTALL) -m 0644 $(@D)/parallel-n64/parallel_n64_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-parallel-n64/
	echo "parallel_n64_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-parallel-n64/.installed_so_name
endef

$(eval $(generic-package))
