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
# platform=unix는 x86_64 데스크톱을 가정해서 HAVE_SSE=1(-mfpmath=sse,
# aarch64엔 없는 옵션)에 desktop GL(GL/gl.h, 이 sysroot엔 GLES만 있고
# 없음) 조합이라 크로스빌드가 통째로 실패함(2026-07-16 실측, 두 에러
# 순서대로 재현). 같은 저장소(libretro/yabause)의 kronos 코어가 이미
# platform=odroid-c4로 이 문제를 풀어놨음(libretro-core-kronos.mk 참고) -
# 이 분기가 HAVE_SSE=0 + FORCE_GLES=1 + C5와 정확히 맞는
# -mcpu=cortex-a55를 전부 자동 설정해줘서 그대로 재사용. kronos가 겪은
# "-lGL 무조건 링크" 문제는 이 브랜치(yabasanshiro) Makefile엔 없음
# (상류 소스 확인, odroid-c4 분기 LDFLAGS에 -lpthread만 있음) - sed
# 패치 불필요.
#
################################################################################

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
	$(MAKE) -C $(@D)/yabause/yabause/src/libretro -f Makefile generate-files
	$(TARGET_MAKE_ENV) $(MAKE) $(LIBRETRO_CORE_YABASANSHIRO_CROSS_OPTS) -C $(@D)/yabause/yabause/src/libretro \
		-f Makefile \
		platform=odroid-c4
endef

define LIBRETRO_CORE_YABASANSHIRO_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-yabasanshiro
	$(INSTALL) -m 0644 $(@D)/yabause/yabause/src/libretro/yabasanshiro_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-yabasanshiro/
	echo "yabasanshiro_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-yabasanshiro/.installed_so_name
endef

$(eval $(generic-package))
