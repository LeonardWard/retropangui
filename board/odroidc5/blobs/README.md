# Proprietary Blobs

이 디렉터리는 ARM 전용 라이선스 파일을 포함하므로 **공개 저장소에서 제외**됩니다.

빌드 전 아래 스크립트로 자동 다운로드하거나 수동으로 파일을 배치하세요.

## 자동 다운로드

```bash
bash board/odroidc5/fetch-blobs.sh
```

## 수동 설치

Hardkernel 공식 Odroid C5 Ubuntu 24.04 이미지 (https://odroid.in/ubuntu_24.04lts/) 에서 추출:

| 이미지 내 경로 | 이 디렉터리 내 경로 |
|----------------|----------------------|
| `/usr/lib/libMali.so` | `mali/libMali.so` |
| `/lib/firmware/mali_csffw.bin` | `mali/lib/firmware/mali_csffw.bin` |
| `/usr/share/vulkan/implicit_layer.d/libVkLayer_window_system_integration.so` | `mali/vulkan/` |
| `/usr/share/vulkan/implicit_layer.d/VkLayer_window_system_integration.json` | `mali/vulkan/` |
| `/usr/share/vulkan/icd.d/mali.json` | `mali/vulkan/` |

## 최종 디렉터리 구조

```
board/odroidc5/blobs/
└── mali/
    ├── libMali.so                    # Mali-G310 Valhall DDK r44p0 (49MB)
    ├── lib/
    │   └── firmware/
    │       └── mali_csffw.bin        # Mali CSF 펌웨어 (264KB)
    └── vulkan/
        ├── mali.json
        ├── VkLayer_window_system_integration.json
        └── libVkLayer_window_system_integration.so
```
