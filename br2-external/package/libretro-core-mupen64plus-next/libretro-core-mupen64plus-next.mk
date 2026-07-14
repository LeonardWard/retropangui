################################################################################
#
# libretro-core-mupen64plus-next - Nintendo 64
#
# 2026-07-12: 첫 빌드 시도에서 "-msse -msse2 unrecognized" 에러로 실패 -
# Makefile이 ARCH 미지정 시 `uname -m`으로 자동감지하는데, 이게 크로스
# 컴파일 빌드 호스트(x86_64 Docker)를 가리켜서 x86_64 SSE 플래그가
# 타겟(aarch64) 컴파일러에 그대로 넘어감. ARCH=aarch64로 명시해서 우회
# (parallel_n64도 같은 패턴, ppsspp는 platform 문자열 자체에 arm64를
# 넣어야 하는 다른 방식).
#
# 2026-07-12 (2차): ARCH 수정 후 재시도에서 "GL/gl.h: No such file or
# directory"로 다시 실패 - platform=unix 기본값이 데스크탑 OpenGL
# (GLideN64 렌더러가 GL/gl.h를 include)을 가정하는데, C5는 Mali GPU라
# GLES2/3만 제공함(mesa3d는 빌드타임 헤더용, 런타임은 libMali.so).
# FORCE_GLES=1을 넘겨서 GLESv2로 링크하도록 강제(parallel_n64도 동일 -
# 둘 다 GLideN64 기반 렌더러라 같은 문제를 공유함).
#
# 2026-07-14: libretro-cores.mk에서 분리(todo-20260712-libretro-cores-package-split).
# 빌드 커맨드는 원본과 동일.
#
################################################################################

LIBRETRO_CORE_MUPEN64PLUS_NEXT_VERSION = 98c1b0d877542b01314b3b04272282ba223b65b3
LIBRETRO_CORE_MUPEN64PLUS_NEXT_SITE = https://github.com/libretro/mupen64plus-libretro-nx
LIBRETRO_CORE_MUPEN64PLUS_NEXT_SOURCE =
LIBRETRO_CORE_MUPEN64PLUS_NEXT_DEPENDENCIES = mesa3d

LIBRETRO_CORE_MUPEN64PLUS_NEXT_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_MUPEN64PLUS_NEXT_BUILD_CMDS
	test -d $(@D)/mupen64plus-libretro-nx/.git || \
		git clone --filter=blob:none $(LIBRETRO_CORE_MUPEN64PLUS_NEXT_SITE) $(@D)/mupen64plus-libretro-nx
	git -C $(@D)/mupen64plus-libretro-nx checkout $(LIBRETRO_CORE_MUPEN64PLUS_NEXT_VERSION)
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/mupen64plus-libretro-nx \
		$(LIBRETRO_CORE_MUPEN64PLUS_NEXT_CROSS_OPTS) \
		platform=unix \
		ARCH=aarch64 \
		FORCE_GLES=1
endef

define LIBRETRO_CORE_MUPEN64PLUS_NEXT_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-mupen64plus-next
	$(INSTALL) -m 0644 $(@D)/mupen64plus-libretro-nx/mupen64plus_next_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-mupen64plus-next/
	echo "mupen64plus_next_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-mupen64plus-next/.installed_so_name
endef

$(eval $(generic-package))
