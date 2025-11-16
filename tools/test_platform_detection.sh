#!/usr/bin/env bash

# =======================================================
# 플랫폼 감지 테스트 스크립트
# 파일명: test_platform_detection.sh
# 설명: 플랫폼 감지 및 설정 로드를 테스트합니다
# 사용법: ./test_platform_detection.sh [--lang=en|--lang=ko]
# =======================================================

# 커맨드라인 인자에서 언어 옵션 파싱
for arg in "$@"; do
    case "$arg" in
        --lang=en|--english|--en)
            export RETROPANGUI_LANG="en"
            ;;
        --lang=ko|--korean|--ko|--한국어)
            export RETROPANGUI_LANG="ko"
            ;;
    esac
done

# config.sh 로드
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

echo "========================================"
echo "$(msg 'test_title')"
echo "========================================"
echo ""

echo "1. $(msg 'basic_info')"
echo "----------------------------------------"
echo "$(msg 'architecture') (uname -m): $(uname -m)"
echo "$(msg 'platform_flags_info') (__platform): $__platform"
echo "$(msg 'architecture') (__platform_arch): $__platform_arch"
echo ""

echo "2. $(msg 'device_detection')"
echo "----------------------------------------"
echo "$(msg 'detected_device') (__device): $__device"
if [ -f /proc/device-tree/model ]; then
    echo "$(msg 'device_tree_model'): $(tr -d '\0' < /proc/device-tree/model)"
else
    echo "Device Tree: $(msg 'none') (x86_64 $(msg 'unknown') ARM)"
fi
echo ""

echo "3. $(msg 'cpu_optimization')"
echo "----------------------------------------"
echo "$(msg 'cpu_flags') (__default_cpu_flags): $__default_cpu_flags"
echo "$(msg 'optimization_flags') (__default_opt_flags): $__default_opt_flags"
echo "$(msg 'gcc_version') (__gcc_version): $__gcc_version"
echo ""

echo "4. $(msg 'platform_flags_info')"
echo "----------------------------------------"
echo "$(msg 'flags_count'): ${#__platform_flags[@]}"
echo "$(msg 'flags_list'):"
for flag in "${__platform_flags[@]}"; do
    echo "  - $flag"
done
echo ""

echo "5. $(msg 'config_files')"
echo "----------------------------------------"
echo "$(msg 'config_directory'): $PLATFORMS_DIR"
echo "$(msg 'config_loaded'): $PLATFORM_CONFIG_LOADED"
echo "$(msg 'loaded_config'): $PLATFORM_CONFIG_FILE"
echo ""

if [ "$PLATFORM_CONFIG_LOADED" = "yes" ]; then
    echo "6. $(msg 'retroarch_config')"
    echo "----------------------------------------"
    echo "$(msg 'retroarch_version'): ${RA_VERSION:-$(msg 'latest') (master)}"
    echo "$(msg 'retroarch_branch'): ${RA_BRANCH:-master}"
    echo ""

    echo "7. $(msg 'gpu_backends')"
    echo "----------------------------------------"
    echo "OpenGL: ${USE_OPENGL:-no}"
    echo "OpenGL ES: ${USE_GLES:-no}"
    echo "Vulkan: ${USE_VULKAN:-no}"
    echo "KMS: ${USE_KMS:-no}"
    echo "Wayland: ${USE_WAYLAND:-no}"
    echo "X11: ${USE_X11:-no}"
    echo ""

    echo "8. $(msg 'build_options')"
    echo "----------------------------------------"
    echo "PLATFORM_CFLAGS: ${PLATFORM_CFLAGS:-($(msg 'none'))}"
    echo "PLATFORM_MAKEFLAGS: ${PLATFORM_MAKEFLAGS:--j$(nproc)}"
    echo "$(msg 'optimization_flags'): ${OPT_LEVEL:--O2}"
    echo ""

    echo "9. $(msg 'enabled_cores')"
    echo "----------------------------------------"
    if [ ${#PLATFORM_ENABLED_CORES[@]} -gt 0 ]; then
        echo "$(msg 'core_count'): ${#PLATFORM_ENABLED_CORES[@]}"
        echo "$(msg 'first_cores'):"
        for i in {0..4}; do
            if [ -n "${PLATFORM_ENABLED_CORES[$i]}" ]; then
                echo "  - ${PLATFORM_ENABLED_CORES[$i]}"
            fi
        done
    else
        echo "$(msg 'core_list_undefined')"
    fi
    echo ""

    echo "10. $(msg 'configure_options')"
    echo "----------------------------------------"
    if [ ${#RA_CONFIGURE_OPTS[@]} -gt 0 ]; then
        echo "$(msg 'option_count'): ${#RA_CONFIGURE_OPTS[@]}"
        echo "$(msg 'option_list'):"
        for opt in "${RA_CONFIGURE_OPTS[@]}"; do
            echo "  $opt"
        done
    else
        echo "$(msg 'default_options')"
    fi
else
    echo "6. $(msg 'warning')"
    echo "----------------------------------------"
    echo "$(msg 'no_platform_config')"
fi

echo ""
echo "========================================"
echo "$(msg 'test_complete')"
echo "========================================"
