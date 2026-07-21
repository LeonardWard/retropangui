################################################################################
#
# libretro-core-mame2016 - MAME 0.174 (2016년 MAME 기준 아케이드 롬셋)
#
# 2026-07-19: arcade 시스템 코어로 추가했으나, x86_64 전용 genie/premake
# 빌드 시스템이라 aarch64(odroidc5) 크로스컴파일이 근본적으로 안 맞음이
# 확인되어 defconfig에서 비활성화(소스/패키지 정의는 유지).
#
# 시행착오 요약(총 6라운드, todo-core-lr-mame2016.html에 상세 기록):
# genie/m68kmake(host 전용 빌드 도구)가 부모의 크로스 CC를 그대로 물려받아
# aarch64로 컴파일되어 실행 자체가 안 됨 -> genie가 만드는 config
# (libretro32/libretro64뿐)와 우리가 넘긴 PTR64/ARCHITECTURE 조합이 계속
# 어긋남 -> genie가 64bit config엔 무조건 -m64(x86 전용 GCC 옵션)를
# 하드코딩 -> NOASM 자동감지도 UNAME(빌드 호스트) 기반이라 크로스컴파일
# 환경에서 빗나감. 공식 Makefile.libretro 래퍼까지 확인했지만
# (aarch64는 이 코어의 공식 CI가 한 번도 검증한 적 없는 영역), 근본
# 원인은 genie/premake 자체가 "64bit=x86_64"를 전제하는 구조라는 점 -
# recalbox/batocera 참고 코드도 실제로는 aarch64에서 검증 안 된 죽은
# 패키지였음(recalbox: 어떤 defconfig에서도 이 코어를 안 켬, batocera:
# 이 코어 자체가 없음).
#
# 결론(2026-07-19 사용자 확정): x86_64 타겟(향후 x86 빌드)에는 기본
# 옵션으로 넣고, aarch64(odroidc5)에서는 defconfig에서 뺀다. 아래
# 옵션은 x86_64 네이티브 빌드를 상정한 기본형 - host==target이라
# genie/m68kmake host 사전빌드, NOASM, ARCH="", -m64 sed 제거 등의
# aarch64 전용 우회가 전부 불필요해짐.
#
################################################################################

LIBRETRO_CORE_MAME2016_SOURCE =

LIBRETRO_CORE_MAME2016_OPTS = \
	platform="unix" \
	LIBRETRO_CPU="$(BR2_ARCH)" \
	LIBRETRO_OS="unix" \
	CONFIG="libretro" \
	OSD="retro" \
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
