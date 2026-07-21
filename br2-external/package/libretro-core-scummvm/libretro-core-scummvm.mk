################################################################################
#
# libretro-core-scummvm - Point-and-click adventures
#
# 2026-07-14: libretro-cores.mk에서 분리(todo-20260712-libretro-cores-package-split).
# 빌드 커맨드는 원본과 동일.
#
################################################################################

LIBRETRO_CORE_SCUMMVM_SOURCE =
LIBRETRO_CORE_SCUMMVM_DEPENDENCIES = mesa3d
LIBRETRO_CORE_SCUMMVM_LICENSE = GPL-2.0

# configure_submodules.sh가 의존하는 두 서브레포
LIBRETRO_CORE_SCUMMVM_DEPS_PATH = $(@D)/scummvm/backends/platform/libretro/deps
LIBRETRO_CORE_SCUMMVM_DEPS_URL    = https://github.com/libretro/libretro-deps
LIBRETRO_CORE_SCUMMVM_DEPS_COMMIT = 7e6e34f0319f4c7448d72f0e949e76265ccf55a1
LIBRETRO_CORE_SCUMMVM_COMMON_URL    = https://github.com/libretro/libretro-common
LIBRETRO_CORE_SCUMMVM_COMMON_COMMIT = 70ed90c42ddea828f53dd1b984c6443ddb39dbd6

define LIBRETRO_CORE_SCUMMVM_BUILD_CMDS
	test -d $(@D)/scummvm/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_SCUMMVM_SITE) $(@D)/scummvm
	git -C $(@D)/scummvm checkout $(LIBRETRO_CORE_SCUMMVM_VERSION)
	mkdir -p $(LIBRETRO_CORE_SCUMMVM_DEPS_PATH)
	# libretro-deps: configure_submodules.sh는 commit hash fetch로 실패하므로 직접 클론
	test -f $(LIBRETRO_CORE_SCUMMVM_DEPS_PATH)/libretro-deps/Makefile || \
		(rm -rf $(LIBRETRO_CORE_SCUMMVM_DEPS_PATH)/libretro-deps && \
		 git clone --filter=blob:none $(LIBRETRO_CORE_SCUMMVM_DEPS_URL) $(LIBRETRO_CORE_SCUMMVM_DEPS_PATH)/libretro-deps && \
		 git -C $(LIBRETRO_CORE_SCUMMVM_DEPS_PATH)/libretro-deps checkout $(LIBRETRO_CORE_SCUMMVM_DEPS_COMMIT))
	# libretro-common: 동일
	test -f $(LIBRETRO_CORE_SCUMMVM_DEPS_PATH)/libretro-common/README.md || \
		(rm -rf $(LIBRETRO_CORE_SCUMMVM_DEPS_PATH)/libretro-common && \
		 git clone --filter=blob:none $(LIBRETRO_CORE_SCUMMVM_COMMON_URL) $(LIBRETRO_CORE_SCUMMVM_DEPS_PATH)/libretro-common && \
		 git -C $(LIBRETRO_CORE_SCUMMVM_DEPS_PATH)/libretro-common checkout $(LIBRETRO_CORE_SCUMMVM_COMMON_COMMIT))
	# 2026-07-14: FORCE_OPENGLES2=1(GLES2 HW 렌더 강제)을 시도했다가 원복함.
	# platform=unix 기본값은 데스크탑 OpenGL을 요청해 RA(OpenGLES만 지원)에서
	# 매번 "Cannot use HW context" 로그 후 소프트웨어 폴백이 뜨는데, 이건 그냥
	# 로그 노이즈일 뿐 실사용엔 문제 없었음. FORCE_OPENGLES2=1로 GLES2 HW
	# 컨텍스트 요청 자체는 성공시켰지만(Mali-G310), 실측 결과 이 GPU에서
	# scummvm 2D 콘텐츠엔 텍스처 업로드+드로우 왕복 오버헤드가 소프트웨어
	# 블릿보다 오히려 버벅임을 유발함(RA 드라이버 전환/오디오 레이턴시 문제가
	# 아니라 GLES2 HW 경로 자체의 성능 특성으로 실측 확인 - ScummVM.cfg
	# video_driver 코어 오버라이드로 드라이버 전환을 없애도 동일하게 버벅임).
	# 소프트웨어 렌더링이 이 콘텐츠엔 더 낫다는 결론 - hw_acceleration
	# 기본값은 ScummVM.opt 번들 파일(rootfs-overlay)로 명시적으로 disabled.
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/scummvm/backends/platform/libretro \
		CC="$(TARGET_CC)" \
		CXX="$(TARGET_CXX)" \
		AR="$(TARGET_AR) cru" \
		RANLIB="$(TARGET_RANLIB)" \
		STRIP="$(TARGET_STRIP)" \
		OBJCOPY="$(TARGET_OBJCOPY)" \
		platform=unix \
		BUILD_64BIT=1
endef

define LIBRETRO_CORE_SCUMMVM_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-scummvm
	$(INSTALL) -m 0644 $(@D)/scummvm/backends/platform/libretro/scummvm_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-scummvm/
	echo "scummvm_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-scummvm/.installed_so_name
	# 2026-07-14: SCUMMVM_THEME_SUBDIR="theme" (Makefile.common) - 코어가
	# <system dir>/scummvm/theme/ 에서 테마 파일을 찾음(libretro-os-utils.cpp
	# s_themeDir). scummvm/ 바로 밑에 평평하게 설치하면 코어가 "테마 폴더
	# 없음"으로 판정해 못 찾음(실기기에서 확인된 배치 오류).
	mkdir -p $(TARGET_DIR)/usr/share/retropangui/bundled-bios/scummvm/theme
	$(INSTALL) -m 0644 $(@D)/scummvm/gui/themes/gui-icons.dat \
		$(TARGET_DIR)/usr/share/retropangui/bundled-bios/scummvm/theme/
	$(INSTALL) -m 0644 $(@D)/scummvm/gui/themes/scummclassic.zip \
		$(TARGET_DIR)/usr/share/retropangui/bundled-bios/scummvm/theme/
	$(INSTALL) -m 0644 $(@D)/scummvm/gui/themes/scummmodern.zip \
		$(TARGET_DIR)/usr/share/retropangui/bundled-bios/scummvm/theme/
endef

$(eval $(generic-package))
