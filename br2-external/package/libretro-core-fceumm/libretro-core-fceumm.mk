################################################################################
#
# libretro-core-fceumm - NES/Famicom/FDS (BIOS 불필요, FDS 내장 에뮬레이션 지원)
#
# 2026-07-14: libretro-cores.mk(16개 코어 단일 패키지)에서 분리 - 코어
# 하나 고칠 때마다 16개 전부 재빌드되는 문제 해결(todo-20260712-libretro-cores-package-split).
# 빌드 커맨드는 원본과 동일(무변경) - 리팩터 자체가 빌드 결과를 바꾸면 안 됨.
#
################################################################################

LIBRETRO_CORE_FCEUMM_VERSION = c0c52ad0eb36cdbfc66e9bdb72efc83103e85e22
LIBRETRO_CORE_FCEUMM_SITE = https://github.com/libretro/libretro-fceumm
LIBRETRO_CORE_FCEUMM_SOURCE =
LIBRETRO_CORE_FCEUMM_DEPENDENCIES = mesa3d

LIBRETRO_CORE_FCEUMM_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_FCEUMM_BUILD_CMDS
	test -d $(@D)/libretro-fceumm/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_FCEUMM_SITE) $(@D)/libretro-fceumm
	git -C $(@D)/libretro-fceumm checkout $(LIBRETRO_CORE_FCEUMM_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/libretro-fceumm \
		-f Makefile.libretro \
		$(LIBRETRO_CORE_FCEUMM_CROSS_OPTS) \
		platform=unix
endef

define LIBRETRO_CORE_FCEUMM_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-fceumm
	$(INSTALL) -m 0644 $(@D)/libretro-fceumm/fceumm_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-fceumm/
	echo "fceumm_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-fceumm/.installed_so_name
endef

$(eval $(generic-package))
