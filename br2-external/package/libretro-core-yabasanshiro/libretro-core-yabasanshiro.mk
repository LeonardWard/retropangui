################################################################################
#
# libretro-core-yabasanshiro - Sega Saturn (Yabause 계열, OpenGL/GLES 가속)
#
# 2026-07-16: libretro/yabause 저장소의 yabasanshiro 브랜치. 다른 코어들과
# 달리 최상위가 아니라 yabause/src/libretro/ 에서 빌드(모노레포 구조 -
# yabause/, yabauseut/, mini18n/ 등이 같은 저장소 안에 있음, 상류 소스
# 트리 확인). GL/GLES 렌더링 코드 있음(vidogl.c 등) - mesa3d 의존.
# .gitmodules는 retro_arena/nanogui-sdl(GUI 데모 도구) 전용 서브모듈이라
# libretro 코어 빌드와 무관 - 서브모듈 없이 클론.
#
################################################################################

LIBRETRO_CORE_YABASANSHIRO_VERSION = f448097b69a6037246a08e9dc09eabaa420d7893
LIBRETRO_CORE_YABASANSHIRO_SITE = https://github.com/libretro/yabause
LIBRETRO_CORE_YABASANSHIRO_SOURCE =
LIBRETRO_CORE_YABASANSHIRO_DEPENDENCIES = mesa3d

LIBRETRO_CORE_YABASANSHIRO_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_YABASANSHIRO_BUILD_CMDS
	test -d $(@D)/yabause/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_YABASANSHIRO_SITE) $(@D)/yabause
	git -C $(@D)/yabause checkout $(LIBRETRO_CORE_YABASANSHIRO_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/yabause/yabause/src/libretro \
		$(LIBRETRO_CORE_YABASANSHIRO_CROSS_OPTS) \
		platform=unix
endef

define LIBRETRO_CORE_YABASANSHIRO_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-yabasanshiro
	$(INSTALL) -m 0644 $(@D)/yabause/yabause/src/libretro/yabasanshiro_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-yabasanshiro/
	echo "yabasanshiro_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-yabasanshiro/.installed_so_name
endef

$(eval $(generic-package))
