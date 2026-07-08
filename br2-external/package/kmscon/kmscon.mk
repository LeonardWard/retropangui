################################################################################
#
# kmscon
#
################################################################################

KMSCON_VERSION = 10.0.1
KMSCON_SITE = https://github.com/kmscon/kmscon/archive/refs/tags
KMSCON_SOURCE = v$(KMSCON_VERSION).tar.gz
KMSCON_LICENSE = MIT
KMSCON_LICENSE_FILES = COPYING

KMSCON_DEPENDENCIES = host-pkgconf libdrm libxkbcommon freetype fontconfig \
	zlib eudev

# libtsm(터미널 상태 머신)은 kmscon이 subprojects/libtsm.wrap(wrap-git)으로
# meson configure 단계에 자동 git clone하는 구조인데, Buildroot의
# meson-package 인프라는 재현 가능한 빌드를 위해 자동 wrap 다운로드를
# 막아놔서("Automatic wrap-based subproject downloading is disabled")
# 그대로 두면 configure가 실패함(2026-07-08 확인). libtsm 자체는 별도
# Buildroot 패키지로 안 만들고, EXTRA_DOWNLOADS로 타르볼을 받아서
# meson이 기대하는 subprojects/libtsm/ 자리에 압축만 풀어넣는 방식으로
# 해결 - meson은 이미 그 자리에 소스가 있으면 다운로드 시도 없이 그냥 씀.
KMSCON_LIBTSM_VERSION = 4.6.0
KMSCON_EXTRA_DOWNLOADS = https://github.com/kmscon/libtsm/archive/refs/tags/v$(KMSCON_LIBTSM_VERSION).tar.gz

define KMSCON_EXTRACT_LIBTSM
	mkdir -p $(@D)/subprojects/libtsm
	$(call suitable-extractor,v$(KMSCON_LIBTSM_VERSION).tar.gz) \
		$(KMSCON_DL_DIR)/v$(KMSCON_LIBTSM_VERSION).tar.gz | \
		$(TAR) --strip-components=1 -C $(@D)/subprojects/libtsm $(TAR_OPTIONS) -
endef
KMSCON_POST_EXTRACT_HOOKS += KMSCON_EXTRACT_LIBTSM

# 2026-07-08: fbterm의 DRM_FBDEV_EMULATION 비호환 문제를 피하려고 도입 -
# drm2d(순수 DRM dumb-buffer, GPU 가속 없음)만 켜고 나머지 비디오
# 백엔드(fbdev, drm3d/GPU가속)는 명시적으로 꺼서 문제가 된 fbdev 경로
# 자체를 원천 차단 + Mali GPU 관련 EGL/GLESv2 복잡도 회피. 폰트는
# freetype만 켜서 Pretendard(한글) 재사용 - pango/unifont는 불필요.
KMSCON_CONF_OPTS = \
	-Dvideo_fbdev=disabled \
	-Dvideo_drm2d=enabled \
	-Dvideo_drm3d=disabled \
	-Drenderer_gltex=disabled \
	-Dfont_freetype=enabled \
	-Dfont_pango=disabled \
	-Dfont_unifont=disabled \
	-Dlibseat=disabled \
	-Ddbus=disabled \
	-Dtests=false \
	-Ddocs=disabled \
	-Dlibtsm:tests=false

$(eval $(meson-package))
