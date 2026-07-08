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

# libtsm(터미널 상태 머신)은 subprojects/libtsm.wrap을 통해 meson이
# configure 단계에서 git clone으로 직접 받아옴(네트워크 필요) - 이
# 프로젝트가 이미 build.sh 단계에서 emulationstation을 git clone하는
# 것과 같은 성격의 네트워크 의존성이라 별도 처리 없이 그대로 둠.

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
	-Ddocs=disabled

$(eval $(meson-package))
