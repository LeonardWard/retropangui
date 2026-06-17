################################################################################
#
# mali-ddk - ARM Mali-G310 Valhall DDK r44p0 (proprietary binary)
#
# 소스: Hardkernel 공식 Ubuntu 이미지에서 추출
# 라이선스: ARM Proprietary (비공개 저장소 전용)
#
# 빌드 전 scripts/fetch-blobs.sh 실행 필요:
#   cd /path/to/retropangui-c5 && bash scripts/fetch-blobs.sh
#
################################################################################

MALI_DDK_VERSION = r44p0
MALI_DDK_LICENSE = ARM Proprietary
MALI_DDK_REDISTRIBUTE_SOURCES = NO
# 자체 파일 복사이므로 Buildroot 자동 다운로드 비활성화
MALI_DDK_SOURCE =

# mesa3d 이후 설치되어 EGL/GBM 심볼릭 링크를 덮어써야 함
MALI_DDK_DEPENDENCIES = mesa3d

MALI_DDK_BLOBS_DIR = $(BR2_EXTERNAL_C5_PANGUI_PATH)/../board/odroidc5/blobs/mali

define MALI_DDK_CHECK_BLOBS
	@if [ ! -f "$(MALI_DDK_BLOBS_DIR)/libMali.so" ]; then \
		echo ""; \
		echo "ERROR: Mali DDK blobs not found!"; \
		echo "  Expected: $(MALI_DDK_BLOBS_DIR)/libMali.so"; \
		echo "  Run: bash scripts/fetch-blobs.sh"; \
		echo "  Or see: board/odroidc5/blobs/README.md"; \
		echo ""; \
		exit 1; \
	fi
endef

MALI_DDK_WRAP_SRC = $(BR2_EXTERNAL_C5_PANGUI_PATH)/package/mali-ddk

define MALI_DDK_BUILD_CMDS
	$(call MALI_DDK_CHECK_BLOBS)
	# EGL 래퍼: eglGetPlatformDisplayEXT + eglQueryString(EGL_MESA_platform_gbm) 제공
	$(TARGET_CC) -shared -fPIC \
		-Wl,-soname,libEGL.so.1 \
		-Wl,--no-as-needed \
		-Wl,--allow-shlib-undefined \
		-o $(@D)/libEGL.so.1.0.0 \
		$(MALI_DDK_WRAP_SRC)/mali_egl_wrap.c \
		$(MALI_DDK_BLOBS_DIR)/libMali.so \
		-ldl
	# GBM 래퍼: ARGB8888/XRGB8888→ABGR8888 변환 + gbm_bo_get_format 수정 + has_free_buffers 캡
	$(TARGET_CC) -shared -fPIC \
		-Wl,-soname,libgbm.so.1 \
		-Wl,--no-as-needed \
		-Wl,--allow-shlib-undefined \
		-o $(@D)/libgbm.so.1.0.0 \
		$(MALI_DDK_WRAP_SRC)/mali_gbm_wrap.c \
		$(MALI_DDK_BLOBS_DIR)/libMali.so \
		-ldl
	# GLES2 래퍼: GLES2 로컬 스코프에서 eglGetPlatformDisplayEXT 제공
	$(TARGET_CC) -shared -fPIC \
		-Wl,-soname,libGLESv2.so.2 \
		-Wl,--no-as-needed \
		-Wl,--allow-shlib-undefined \
		-o $(@D)/libGLESv2.so.2.0.0 \
		$(MALI_DDK_WRAP_SRC)/mali_gles2_wrap.c \
		$(MALI_DDK_BLOBS_DIR)/libMali.so
endef

define MALI_DDK_INSTALL_TARGET_CMDS
	$(call MALI_DDK_CHECK_BLOBS)

	# 메인 라이브러리
	$(INSTALL) -D -m 0755 $(MALI_DDK_BLOBS_DIR)/libMali.so \
		$(TARGET_DIR)/usr/lib/libMali.so

	# Mali CSF 펌웨어
	$(INSTALL) -D -m 0644 $(MALI_DDK_BLOBS_DIR)/lib/firmware/mali_csffw.bin \
		$(TARGET_DIR)/lib/firmware/mali_csffw.bin

	# Vulkan ICD / 레이어 (tarball에 없는 파일은 건너뜀)
	$(if $(wildcard $(MALI_DDK_BLOBS_DIR)/vulkan/libVkLayer_window_system_integration.so), \
		$(INSTALL) -D -m 0755 $(MALI_DDK_BLOBS_DIR)/vulkan/libVkLayer_window_system_integration.so \
			$(TARGET_DIR)/usr/share/vulkan/implicit_layer.d/libVkLayer_window_system_integration.so)
	$(if $(wildcard $(MALI_DDK_BLOBS_DIR)/vulkan/VkLayer_window_system_integration.json), \
		$(INSTALL) -D -m 0644 $(MALI_DDK_BLOBS_DIR)/vulkan/VkLayer_window_system_integration.json \
			$(TARGET_DIR)/usr/share/vulkan/implicit_layer.d/VkLayer_window_system_integration.json)
	$(if $(wildcard $(MALI_DDK_BLOBS_DIR)/vulkan/mali.json), \
		$(INSTALL) -D -m 0644 $(MALI_DDK_BLOBS_DIR)/vulkan/mali.json \
			$(TARGET_DIR)/usr/share/vulkan/icd.d/mali.json)

	# EGL 래퍼 (eglGetPlatformDisplayEXT 제공, SONAME=libEGL.so.1)
	$(INSTALL) -D -m 0755 $(@D)/libEGL.so.1.0.0 \
		$(TARGET_DIR)/usr/lib/libEGL.so.1.0.0
	ln -sf libEGL.so.1.0.0 $(TARGET_DIR)/usr/lib/libEGL.so.1
	ln -sf libEGL.so.1.0.0 $(TARGET_DIR)/usr/lib/libEGL.so

	# GBM 래퍼 (ARGB/XRGB8888→ABGR8888 변환, gbm_bo_get_format 수정, SONAME=libgbm.so.1)
	$(INSTALL) -D -m 0755 $(@D)/libgbm.so.1.0.0 \
		$(TARGET_DIR)/usr/lib/libgbm.so.1.0.0
	ln -sf libgbm.so.1.0.0 $(TARGET_DIR)/usr/lib/libgbm.so.1
	ln -sf libgbm.so.1.0.0 $(TARGET_DIR)/usr/lib/libgbm.so

	# GLES2 래퍼 (SONAME=libGLESv2.so.2)
	$(INSTALL) -D -m 0755 $(@D)/libGLESv2.so.2.0.0 \
		$(TARGET_DIR)/usr/lib/libGLESv2.so.2.0.0
	ln -sf libGLESv2.so.2.0.0 $(TARGET_DIR)/usr/lib/libGLESv2.so.2
	ln -sf libGLESv2.so.2.0.0 $(TARGET_DIR)/usr/lib/libGLESv2.so

	# GLES v1 - Mali가 직접 제공
	ln -sf libMali.so $(TARGET_DIR)/usr/lib/libGLESv1_CM.so
	ln -sf libMali.so $(TARGET_DIR)/usr/lib/libGLESv1_CM.so.1
	ln -sf libMali.so $(TARGET_DIR)/usr/lib/libGLESv1_CM.so.1.1.0

	# Vulkan ICD 호환 symlink — mali.json이 libMaliVulkan.so.1을 참조하는 버전에서도 동작하도록
	ln -sf libMali.so $(TARGET_DIR)/usr/lib/libMaliVulkan.so.1

	# 빈 디렉토리 정리
	rmdir $(TARGET_DIR)/usr/lib/aarch64-linux-gnu 2>/dev/null || true
endef

$(eval $(generic-package))
