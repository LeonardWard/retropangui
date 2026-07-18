################################################################################
#
# libretro-core-mame2016 - MAME 0.174 (2016년 MAME 기준 아케이드 롬셋)
#
# 2026-07-19: arcade 시스템 4번째 코어로 추가.
# genie/premake 기반 빌드 시스템(재귀적으로 자체 빌드툴을 먼저 native로
# 빌드한 뒤 실제 컴파일 makefile을 생성) - fbneo/mame2003-plus/mame2010보다
# 훨씬 무겁고 실패 가능성도 높음. recalbox의 예전 mk는 PYTHON_EXECUTABLE=python2
# 를 썼지만 이 프로젝트 buildroot엔 host-python2가 없음(buildroot 2024.02.1
# 자체가 python2 패키지를 지원 안 함) - 최신 업스트림 makefile을 직접 확인해
# python3도 지원됨을 확인하고 python3로 지정.
# PTR64=1(aarch64=64bit), LIBRETRO_CPU/OS는 buildroot 표준 변수 그대로 전달.
#
################################################################################

LIBRETRO_CORE_MAME2016_VERSION = 3529f4e2cb8e74c88d83bc9fc9d695f78dc9a975
LIBRETRO_CORE_MAME2016_SITE = https://github.com/libretro/mame2016-libretro
LIBRETRO_CORE_MAME2016_SOURCE =

LIBRETRO_CORE_MAME2016_OPTS = \
	platform="unix" \
	LIBRETRO_CPU="$(BR2_ARCH)" \
	LIBRETRO_OS="unix" \
	CONFIG="libretro" \
	OSD="retro" \
	PTR64=1 \
	PYTHON_EXECUTABLE=python3 \
	NOWERROR=1 \
	VERBOSE=1 \
	SUBTARGET=arcade

define LIBRETRO_CORE_MAME2016_BUILD_CMDS
	test -d $(@D)/mame2016/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_MAME2016_SITE) $(@D)/mame2016
	git -C $(@D)/mame2016 checkout $(LIBRETRO_CORE_MAME2016_VERSION)
	mkdir -p $(@D)/mame2016/build/gmake/libretro/obj/x64/libretro/src/osd/retro
	mkdir -p $(@D)/mame2016/3rdparty/genie/build/gmake.linux/obj/Release/src/host
	$(MAKE) CXX="$(TARGET_CXX)" CC="$(TARGET_CC)" LD="$(TARGET_LD)" \
		RANLIB="$(TARGET_RANLIB)" AR="$(TARGET_CC)-ar" \
		-C $(@D)/mame2016 -f makefile $(LIBRETRO_CORE_MAME2016_OPTS)
endef

define LIBRETRO_CORE_MAME2016_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-mame2016
	$(INSTALL) -m 0644 $(@D)/mame2016/mamearcade2016_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-mame2016/mame2016_libretro.so
	echo "mame2016_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-mame2016/.installed_so_name
endef

$(eval $(generic-package))
