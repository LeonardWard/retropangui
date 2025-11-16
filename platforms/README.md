# Retro Pangui 플랫폼별 설정

이 디렉토리는 다양한 하드웨어 플랫폼을 지원하기 위한 플랫폼별 설정 파일을 포함합니다.

## 지원 플랫폼 (테스트 가능)

### x86_64
- **아키텍처**: x86_64 (AMD64)
- **최적화**: `-march=native -mtune=native`
- **GPU**: OpenGL, Vulkan, KMS, X11
- **특징**: 거의 모든 에뮬레이터 코어 지원 (고성능)

### Odroid C5
- **아키텍처**: ARM64 (aarch64)
- **CPU**: Cortex-A55 (4코어)
- **GPU**: Mali-G31 (G310) @ 850MHz
- **최적화**: `-mcpu=cortex-a55 -mtune=cortex-a55`
- **GPU 백엔드**: OpenGL ES 3.2, **Vulkan 1.0+**, KMS, Wayland
- **특징**: 중급 성능, PSX/N64/Dreamcast 지원

### Odroid XU4
- **아키텍처**: ARMv7 (armv7l)
- **CPU**: Cortex-A15 (1.4GHz) + Cortex-A7 (2.0GHz) big.LITTLE (8코어)
- **GPU**: Mali-T628 MP6
- **최적화**: `-mcpu=cortex-a15 -mtune=cortex-a15`
- **GPU 백엔드**: OpenGL ES 3.1, KMS (Vulkan 미지원)
- **특징**: big.LITTLE 구조, 중고급 성능

### Raspberry Pi 3B/3B+
- **아키텍처**: ARMv8/ARMv7 (aarch64/armv7l)
- **CPU**: Cortex-A53 (4코어, 3B: 1.2GHz / 3B+: 1.4GHz)
- **GPU**: VideoCore IV
- **최적화**: `-mcpu=cortex-a53 -mtune=cortex-a53`
- **GPU 백엔드**: OpenGL ES 2.0, KMS (Vulkan 미지원)
- **특징**: 기본 코어 중심 (SNES, Genesis, PSX 등)

### Raspberry Pi 5
- **아키텍처**: ARM64 (aarch64)
- **CPU**: Cortex-A76 (4코어, 2.4GHz)
- **GPU**: VideoCore VII @ 800MHz
- **최적화**: `-mcpu=cortex-a76 -mtune=cortex-a76`
- **GPU 백엔드**: OpenGL ES 3.1, **Vulkan 1.2**, KMS
- **특징**: 고성능, PSP 지원 가능

## 설정 파일 구조

### common.conf
모든 플랫폼에 공통으로 적용되는 기본 설정입니다.
- 기본 활성화 코어 목록
- 기본 빌드 옵션
- 공통 버전 정보

### aarch64.conf / armv7l.conf (Generic Fallback)
알 수 없는 ARM 기기용 안전한 기본 설정입니다.
- **용도 1**: 미지원 기기에서 강제 진행 시 자동 사용
- **용도 2**: 새 플랫폼 추가 시 복사할 템플릿
- **특징**: 보수적 설정 (GLES, KMS, 기본 코어만)

### [기기명].conf
플랫폼별 최적화 설정으로, 최고의 성능을 제공합니다.
- x86_64.conf, odroidc5.conf, rpi5.conf 등
- CPU/GPU별 최적화 플래그
- 플랫폼 성능에 맞는 코어 선택

## 설정 파일 형식

각 플랫폼 설정 파일은 다음과 같은 변수를 정의할 수 있습니다:

```bash
# RetroArch 버전
RA_VERSION="v1.17.0"        # 특정 버전 태그 (빈 값 = 최신)
RA_BRANCH="master"          # Git 브랜치

# 활성화할 코어 목록
PLATFORM_ENABLED_CORES=(
    "lr-genesis-plus-gx"
    "lr-snes9x"
    # ...
)

# 비활성화할 코어 목록
PLATFORM_DISABLED_CORES=(
    "lr-dolphin"            # 너무 무거운 코어
)

# 빌드 옵션
PLATFORM_CFLAGS="-mcpu=cortex-a55 -O3"
PLATFORM_LDFLAGS=""
PLATFORM_MAKEFLAGS="-j4"

# GPU 백엔드
USE_OPENGL="no"
USE_GLES="yes"
USE_VULKAN="no"
USE_KMS="yes"

# RetroArch configure 옵션
RA_CONFIGURE_OPTS=(
    "--prefix=$INSTALL_ROOT_DIR"
    "--enable-opengles"
    "--enable-kms"
    # ...
)
```

## 플랫폼 감지 방식

1. **x86_64**: `uname -m`으로 직접 감지
2. **ARM 계열**: `/proc/device-tree/model`에서 기기 모델 파싱

감지 결과는 `$__device` 변수에 저장됩니다.

## 새로운 플랫폼 추가하기

### 기기가 자동 감지되지 않을 때

Setup 실행 시 다음과 같은 경고가 표시됩니다:

```
⚠️  경고: 플랫폼 설정 파일을 찾을 수 없습니다!

📋 감지된 시스템 정보:
   - 아키텍처: aarch64
   - 감지된 기기: unknown
   - Device-tree 모델: My New Board
```

### 플랫폼 추가 단계

#### 1. 시스템 정보 확인

```bash
# 아키텍처 확인
uname -m

# Device-tree 모델 확인 (ARM 기기)
cat /proc/device-tree/model

# CPU 정보 확인
lscpu
```

#### 2. 유사한 설정 파일 복사

**ARM64 기기:**
```bash
cd /home/pangui/scripts/retropangui/platforms/
cp odroidc5.conf mynewboard.conf
```

**ARMv7 기기:**
```bash
cp odroidxu4.conf mynewboard.conf
```

**x86 기기:**
```bash
cp x86_64.conf mypc.conf
```

#### 3. 기기 감지 로직 추가

`config.sh` 파일을 편집:
```bash
nano /home/pangui/scripts/retropangui/config.sh
```

`detect_device()` 함수에 추가:
```bash
# ARM 계열: device-tree에서 모델명 파싱
if [ -f /proc/device-tree/model ]; then
    local model=$(tr -d '\0' < /proc/device-tree/model)
    case "$model" in
        *"Raspberry Pi 3 Model B Plus"*) echo "rpi3b"; return;;
        *"Raspberry Pi 3 Model B"*) echo "rpi3b"; return;;
        *"Raspberry Pi 5"*) echo "rpi5"; return;;
        *"ODROID-C5"*) echo "odroidc5"; return;;
        *"ODROID-XU4"*) echo "odroidxu4"; return;;
        *"My New Board"*) echo "mynewboard"; return;;  # ← 여기 추가
    esac
fi
```

#### 4. 설정 파일 수정

`platforms/mynewboard.conf` 파일을 편집하여 하드웨어에 맞게 조정:

```bash
# CPU 최적화 플래그
PLATFORM_CFLAGS="-mcpu=cortex-a55 -mtune=cortex-a55"  # CPU에 맞게 변경

# GPU 백엔드 설정
USE_VULKAN="yes"  # GPU에 따라 변경

# RetroArch configure 옵션
RA_CONFIGURE_OPTS=(
    "--prefix=$INSTALL_ROOT_DIR"
    "--enable-vulkan"  # GPU 지원에 따라 수정
    # ...
)
```

#### 5. 테스트

```bash
./test_platform_detection.sh
```

#### 6. Setup 실행

```bash
sudo ./retropangui_setup.sh
```

## 테스트 방법

```bash
# 플랫폼 정보 확인
sudo ./retropangui_setup.sh

# 로그에서 다음 정보 확인:
# - 아키텍처
# - 감지된 기기
# - CPU 플래그
# - 플랫폼 설정 파일
# - RetroArch 버전/브랜치
```

## 버전 고정 전략

현재는 최신 master 브랜치를 사용하도록 설정되어 있습니다 (`RA_VERSION=""`).
안정성이 필요한 경우 특정 버전을 지정할 수 있습니다:

```bash
# 예: RetroArch 1.17.0 버전 사용
RA_VERSION="v1.17.0"
RA_BRANCH=""  # 버전 지정 시 브랜치는 무시됨
```

## 참고사항

- 플랫폼별 설정은 `config.sh` 로드 시 자동으로 적용됩니다
- 설정 로드 순서: `common.conf` → `[플랫폼].conf`
- 나중에 로드된 설정이 이전 설정을 오버라이드합니다
- 레트로파이 설치 스크립트를 활용하는 경우 일부 설정이 무시될 수 있습니다
