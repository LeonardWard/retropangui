################################################################################
#
# libretro-core-kronos - Sega Saturn (GL 가속, beetle_saturn과 별개 코어)
# Batocera의 Odroid C4(S905X3) 레시피(platform=odroid-c4 FORCE_GLES=1) 그대로 사용.
# 저장소 자체가 "yabause" repo 안에 다시 "yabause" 하위 디렉토리를 갖는 구조.
#
# 2026-07-14: libretro-cores.mk에서 분리(todo-20260712-libretro-cores-package-split).
# 빌드 커맨드는 원본과 동일(sed 패치·stdstring 마커·HAVE_SSE=0 우회 포함, 무변경).
#
################################################################################

LIBRETRO_CORE_KRONOS_VERSION = 146f4295eb7f5f76a2e6e6c84518c9bdf6a8398f
LIBRETRO_CORE_KRONOS_SITE = https://github.com/libretro/yabause
LIBRETRO_CORE_KRONOS_SOURCE =
LIBRETRO_CORE_KRONOS_DEPENDENCIES = mesa3d

LIBRETRO_CORE_KRONOS_CROSS_OPTS = \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)"

define LIBRETRO_CORE_KRONOS_BUILD_CMDS
	test -d $(@D)/yabause/.git || \
		git clone --filter=blob:none --recurse-submodules $(LIBRETRO_CORE_KRONOS_SITE) $(@D)/yabause
	git -C $(@D)/yabause checkout $(LIBRETRO_CORE_KRONOS_VERSION)
	git -C $(@D)/yabause submodule update --init --recursive
	# 모든 unix 계열 플랫폼 브랜치가 LDFLAGS에 -lGL(데스크탑 GL)을 무조건
	# 넣는데, FORCE_GLES=1이면 Makefile.common이 -lGLESv2를 따로 추가할 뿐
	# 이미 들어간 -lGL은 안 지워줌 - 우리 sysroot엔 libGL이 없어서 링크
	# 실패("cannot find -lGL"). Batocera도 같은 이유로
	# 001-makefile-remove-bogus-link-GL.patch로 -lGL을 제거하고 있음
	# (레시피의 platform/FORCE_GLES 값만 참고하고 패치 존재를 놓쳤던 것).
	sed -i 's/-lpthread -lGL$$/-lpthread/' $(@D)/yabause/yabause/src/libretro/Makefile
	# Makefile.common이 stdstring.c를 HAVE_CDROM=1 블록 안에만 넣어놨는데,
	# 무조건 포함되는 file_path.c가 string_to_lower()를 항상 호출해서
	# HAVE_CDROM이 꺼진 플랫폼(제네릭 odroid 브랜치 포함)에선 링크가 깨짐
	# ("undefined reference to string_to_lower", WSL2 클린 빌드 실측).
	# 무조건 소스 목록에 추가. 마커 grep은 재실행 시 중복 append 방지
	# (중복되면 ld multiple definition으로 다른 에러가 남).
	grep -q 'rpui-fix-stdstring' $(@D)/yabause/yabause/src/libretro/Makefile.common || \
		echo 'SOURCES_C += $$(LIBRETRO_COMM_DIR)/string/stdstring.c # rpui-fix-stdstring' \
			>> $(@D)/yabause/yabause/src/libretro/Makefile.common
	$(MAKE) -C $(@D)/yabause/yabause/src/libretro -f Makefile generate-files
	# platform=odroid-c4는 "findstring odroid" 제네릭 브랜치를 타는데, 이
	# 브랜치는 /proc/cpuinfo를 grep해서 XU3/XU4인지 확인한 뒤에만
	# HAVE_SSE=0을 설정함 - 크로스 빌드 컨테이너엔 당연히 "odroid" 문자열이
	# 없어서(빌드 호스트지 실제 기기가 아니므로) 이 하위 분기가 전혀 안
	# 타고, 결국 파일 맨 위 기본값 HAVE_SSE=1(x86 SSE)이 그대로 살아남아
	# -msse -mfpmath=sse가 크로스 컴파일러로 새어들어감(N64 코어들의
	# ARCH=aarch64 문제와 같은 종류, 감지 대상이 다를 뿐). 커맨드라인에서
	# HAVE_SSE=0을 명시해서 우회(파일 내부 "=" 대입은 커맨드라인 변수를
	# 못 이김).
	$(TARGET_CONFIGURE_OPTS) $(MAKE) $(LIBRETRO_CORE_KRONOS_CROSS_OPTS) -C $(@D)/yabause/yabause/src/libretro \
		-f Makefile \
		platform=odroid-c4 \
		FORCE_GLES=1 \
		HAVE_SSE=0
endef

define LIBRETRO_CORE_KRONOS_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/libretro/lr-kronos
	$(INSTALL) -m 0644 $(@D)/yabause/yabause/src/libretro/kronos_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/lr-kronos/
	echo "kronos_libretro.so" > $(TARGET_DIR)/usr/lib/libretro/lr-kronos/.installed_so_name
endef

$(eval $(generic-package))
