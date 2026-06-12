# Retro Pang UI

레트로 게이밍 OS. 현재 지원 기기: **Odroid C5** (Amlogic S905X5M).

## 시스템 요구사항 (빌드 환경)

- Docker 26.0 이상
- 최소 8GB RAM
- 최소 50GB 디스크 여유 공간
- 빌드 시간: 2-4시간 (첫 빌드 기준)

## 빌드

```bash
cd /path/to/retropangui

# 기기 지정 (기본: odroidc5, 버전은 Git 태그 자동 인식)
./build.sh odroidc5

# 버전 지정
VERSION=1.0.0 ./build.sh odroidc5

# 클린 빌드 (빌드 캐시 삭제, 다운로드 캐시 유지)
rm -rf buildroot/output/
./build.sh odroidc5

# 부분 빌드 (gamepad-mgr 소스 수정 후 빠른 재빌드)
./build.sh --partial
./build.sh odroidc5 --partial
```

> **참고**: emulationstation은 브랜치(main) 추적 패키지라서 전체 빌드 시
> `build.sh`가 dl 캐시(tarball + git)를 자동 삭제하고 항상 최신 main을 받아 빌드합니다.
> 부분 빌드(`--partial`)는 ES를 건드리지 않으므로 캐시를 유지합니다.

출력: `output/retropangui-<device>-<version>.img`

버전은 `VERSION` 환경변수가 없으면 `git describe --tags --always`로 자동 결정됩니다.
`git tag v0.2` 후 빌드하면 `retropangui-odroidc5-0.2.img`가 생성됩니다.

지원되는 기기 목록은 `configs/retropangui-*_defconfig` 파일 이름으로 확인할 수 있습니다.
잘못된 기기명을 입력하면 목록을 출력합니다.

### Mali DDK 블롭

`build.sh`가 `scripts/fetch-blobs.sh`를 자동 호출하여
Hardkernel 공식 Yocto 레이어([meta-odroid-aml](https://github.com/mdrjr/meta-odroid-aml))에서
Mali-G310 DDK 바이너리(`libMali.so`, `mali_csffw.bin` 등 ~100MB)를 다운로드합니다.
이미 있으면 스킵.

수동 재다운로드:
```bash
rm -rf board/odroidc5/blobs/mali/
bash scripts/fetch-blobs.sh
```

### 증분 빌드 (특정 패키지만)

gamepad-mgr 소스 수정 후 빠른 재빌드 (`--partial` 옵션):
```bash
# board 파일 동기화 + gamepad-mgr 재빌드 + 이미지 재패킹만 수행
./build.sh --partial
```

mali-ddk 래퍼 소스 수정 후:
```bash
rm -f buildroot/output/build/mali-ddk-r44p0/.stamp_built \
       buildroot/output/build/mali-ddk-r44p0/.stamp_staging_installed \
       buildroot/output/build/mali-ddk-r44p0/.stamp_target_installed
./build.sh odroidc5
```

RetroArch 패치 수정 후 (buildroot/output/ 유지하면서):
```bash
rm -f buildroot/output/build/retroarch-v1.22.2/.stamp_built \
       buildroot/output/build/retroarch-v1.22.2/.stamp_installed
./build.sh odroidc5
```

## 플래싱

헬퍼 스크립트를 사용하면 SD카드/eMMC를 자동 탐지하여 플래싱합니다:

```bash
bash scripts/flash-sd.sh                                        # 최신 이미지 자동 선택
bash scripts/flash-sd.sh output/retropangui-odroidc5-1.0.0.img # 이미지 직접 지정
```

SD카드와 eMMC 모두 지원합니다. 장치가 여러 개이면 목록에서 선택합니다.

직접 dd로 플래싱할 경우:

```bash
sudo dd if=output/retropangui-odroidc5-1.0.0.img of=/dev/sdX bs=4M status=progress conv=fsync
```

## 접속

| 방법 | 주소 |
|------|------|
| SSH (hostname) | `ssh root@retropangui-c5.lan` |
| SSH (IP) | `ssh root@<IP>` |
| SFTP (FileZilla 등) | `sftp://root@retropangui-c5.lan` |
| 기본 비밀번호 | `odroid` |

SSH/SFTP는 OpenSSH(`sshd` + `sftp-server`)로 통합 운영됩니다.
FileZilla, WinSCP, Cyberduck 등 SFTP 클라이언트로 롬·BIOS·세이브 파일을 직접 전송할 수 있습니다.

## 파티션 구조

| 파티션 | 파일시스템 | 크기 | 용도 |
|--------|----------|------|------|
| p1 | FAT32 | 128MB | 부트 (kernel, dtb, boot.scr) |
| p2 | ext4 | 8GB | rootfs (OS, RetroArch, 코어) |
| p3 | exFAT | 나머지 전부 | Share (ROMs, BIOS, 세이브) |

**Share 파티션(p3)은 첫 부팅 시 자동 생성됩니다.**
- 첫 부팅: 파티션 생성 후 자동 재부팅
- 두 번째 부팅: exFAT 포맷 후 `/retropangui/share` 마운트

Windows/Mac에서 SD카드 연결 시 `share` 드라이브로 인식됩니다.

### Share 디렉토리 구조

```
/retropangui/share/            (exFAT 파티션 루트 마운트)
├── roms/                      # 롬 파일
│   ├── nes/
│   ├── snes/
│   └── psx/
├── bios/                      # BIOS 파일
├── saves/                     # 세이브 파일 + 스테이트 (시스템별 폴더, 예: saves/snes/)
├── screenshots/               # 스크린샷
├── music/                     # 배경음악 (mp3/ogg/flac/wav/m4a — ES가 셔플 재생)
└── system/
    ├── retroarch/
    │   └── retroarch.cfg      # 사용자 RetroArch 설정 (첫 부팅 시 기본값 복사)
    └── emulationstation/      # ES 설정, 테마, 입력 설정
```

## 프로젝트 구조

```
retropangui/
├── build.sh                      # 빌드 진입점 (./build.sh [device])
├── scripts/
│   ├── fetch-blobs.sh            # Mali DDK 블롭 자동 다운로드
│   └── flash-sd.sh               # SD카드 플래싱 헬퍼
├── configs/
│   └── retropangui-odroidc5_defconfig  # Odroid C5용 Buildroot 설정
├── board/odroidc5/
│   ├── boot.cmd                  # boot.scr 소스
│   ├── genimage.cfg              # SD카드 이미지 파티션 레이아웃
│   ├── post-build.sh             # rootfs 커스터마이징
│   ├── post-image.sh             # 이미지 생성 후처리
│   ├── u-boot.bin.sd.bin         # U-Boot 바이너리 (Hardkernel)
│   ├── blobs/mali/               # Mali DDK 블롭 (fetch-blobs.sh로 생성)
│   └── rootfs-overlay/
│       ├── etc/
│       │   ├── asound.conf
│       │   ├── gamepad/
│       │   │   ├── gamecontrollerdb.txt  # SDL2 커스텀 매핑 (ES용, PS2 어댑터 + 가상 패드)
│       │   │   └── gamepad_config.json   # GUID 슬롯 히스토리 + SDL 매핑
│       │   ├── retroarch/
│       │   │   └── autoconfig/           # RetroArch udev 패드 매핑
│       │   │       ├── RetroPangUI P1~P4.cfg  # 가상 패드 자동 인식
│       │   │       └── PS2 USB Adapter.cfg    # 어댑터 직접 연결 시
│       │   ├── udev/rules.d/
│       │   │   ├── 50-odroid-gpu-mali.rules
│       │   │   ├── 70-hdmi-hotplug.rules
│       │   │   └── 99-gamepad.rules      # /dev/input 퍼미션
│       │   └── init.d/
│       │       ├── S49ntp        # NTP + fake-hwclock
│       │       ├── S58gamepad    # gamepad-daemon (uinput 가상 패드, ES/RA 이전 시작)
│       │       ├── S60display    # HDMI 초기화 (odroid-drm-fbset)
│       │       ├── S61share      # Share 파티션 자동 생성/포맷/마운트
│       │       ├── S62audio      # ALSA 믹서 복원
│       │       ├── S91ksmbd      # SMB3 파일 공유
│       │       ├── S95retropangui # 설정 초기화 + CPU/GPU performance 거버너
│       │       └── S99emulationstation  # ES 자동 실행
│       └── opt/retropangui/
│           └── retroarch.cfg     # RetroArch 기본 설정 (첫 부팅 시 /retropangui/share/system/retroarch/로 복사)
├── br2-external/
│   ├── patches/retroarch/
│   │   └── 0001-drm-ctx-mali-valhall-*.patch  # RetroArch KMS/DRM 패치 (6개 수정)
│   └── package/
│       ├── mali-ddk/
│       │   ├── mali-ddk.mk
│       │   ├── mali_egl_wrap.c       # EGL 래퍼
│       │   ├── mali_gbm_wrap.c       # GBM 래퍼 (포맷 변환 + bo 포맷 수정)
│       │   └── mali_gles2_wrap.c     # GLES2 래퍼
│       └── gamepad-mgr/
│           ├── gamepad-mgr.mk
│           └── src/
│               ├── gamepad.h/c         # 공개 API (SDL2 통합, 이벤트 콜백)
│               ├── gamepad_slot.h/c    # Player 1~4 슬롯 매니저 (GUID 기반 복원)
│               ├── gamepad_mapping.h/c # 커스텀 매핑 로드/저장
│               ├── gamepad_vdev.h/c    # uinput 가상 장치 생성 + FF 패스스루
│               ├── gamepad_daemon.c    # 데몬 진입점 (125Hz 루프)
│               └── gamepad_test.c      # 현장 디버깅 도구
├── buildroot/
│   └── internal_build.sh         # Docker 내부 빌드 스크립트
├── dl/                           # 다운로드 캐시 (자동 생성)
└── output/                       # 빌드 결과물
```

## 부트 흐름

```
U-Boot (mmc 1) → boot.scr (p1 FAT) → kernel Image + DTB → rootfs (p2 ext4)
```

- SD카드 = mmc 1 = mmcblk1 / eMMC = mmc 0 = mmcblk0
- 커널 로드 주소: `0x03080000` / DTB 로드 주소: `0x01000000`

## 주요 커널 파라미터

```
root=/dev/mmcblk${devnum}p2 rootwait rw
vout=1920x1080p60hz,enable
connector0_type=HDMI-A-A
hdmimode=1920x1080p60hz
hdmitx=,422,12bit
```

`${devnum}`은 U-Boot 런타임에 치환됩니다: SD=1 (`mmcblk1p2`), eMMC=0 (`mmcblk0p2`).

## GPU / Mali DDK

### 구조

Mali-G310 Valhall (r44p0)은 전용 바이너리 `libMali.so` 하나에 EGL/GLES/Vulkan/GBM이
모두 포함됩니다. 래퍼 라이브러리 3개로 RetroArch/Kodi/EmulationStation 호환성을 확보합니다.

| 래퍼 | SONAME | 역할 |
|------|--------|------|
| `mali_egl_wrap.c` | `libEGL.so.1` | `eglGetPlatformDisplayEXT` 제공 (Mesa GBM platform 지원) |
| `mali_gbm_wrap.c` | `libgbm.so.1` | 포맷 변환 + GBM BO 포맷 수정 (아래 참고) |
| `mali_gles2_wrap.c` | `libGLESv2.so.2` | SDL2 RTLD_LOCAL 스코프용 EGL 제공 |

### GBM 래퍼 상세 (`mali_gbm_wrap.c`)

Mali Valhall 내부 픽셀 포맷은 `ABGR8888` (byte0=R)입니다.

| 인터셉트 함수 | 처리 내용 |
|--------------|----------|
| `gbm_surface_create` | `ARGB8888`, `XRGB8888` → `ABGR8888` 변환 |
| `gbm_surface_create_with_modifiers` | 동일, AFBC modifier 유지 |
| `gbm_bo_get_format` | `XRGB8888` 또는 `< 0x01000000` (invalid fourcc) → `ABGR8888` 반환 |
| `gbm_surface_has_free_buffers` | 동시 lock 2개 초과 시 0 반환 (Kodi EGL_BAD_ALLOC 방지) |

> `gbm_bo_get_format`이 `0x1` 같은 invalid 값을 반환하는 경우가 있음.
> DRM fourcc는 항상 4-ASCII 코드 (`≥ 0x20202020`)이므로 `< 0x01000000`이면 ABGR8888로 대체.

### EGL 래퍼 상세 (`mali_egl_wrap.c`)

Mali EGL은 `EGL_EXT_platform_base`를 지원하지만 `eglGetPlatformDisplayEXT`를
직접 export하지 않아 Mesa/SDL2가 찾지 못합니다. 래퍼가 이를 제공합니다.

> `RTLD_NEXT` 대신 `dlopen("libMali.so", RTLD_NOLOAD)`를 사용.
> libMali.so가 libgbm.so.1/libEGL.so.1보다 먼저 로드될 경우 RTLD_NEXT가 Mali 심볼을 건너뜀.

## RetroArch KMS/DRM 패치

`br2-external/patches/retroarch/0001-drm-ctx-mali-valhall-argb8888-drmModeAddFB2.patch`

RetroArch v1.22.2의 `gfx/drivers_context/drm_ctx.c`에 Mali-G310 호환을 위한 6개 수정:

### 1. GLES API switch 문 버그 (SIGSEGV)

`case GFX_CTX_OPENGL_ES_API:`가 `#ifdef HAVE_OPENGL` 블록 안에 있어서
`HAVE_OPENGL=0`인 빌드에서 케이스 레이블이 사라지고 `attrib_ptr`이 NULL로 남음.
EGL 컨텍스트 생성 후 `for (; *attrib_ptr != EGL_NONE; ...)` 루프에서 SIGSEGV.

→ `case GFX_CTX_OPENGL_ES_API:`를 `#ifdef HAVE_OPENGL` 밖으로, `#ifdef HAVE_OPENGLES`로 감쌈.

### 2. EGL config 선택 실패 (EGL_BAD_CONFIG)

`gbm_choose_xrgb8888_cb`가 `EGL_NATIVE_VISUAL_ID == GBM_FORMAT_XRGB8888`인 config만 허용.
Mali EGL 래퍼가 `ARGB8888`을 `NATIVE_VISUAL_ID`로 보고함 → 조건 불일치, config 선택 실패.

→ `id == GBM_FORMAT_XRGB8888 || id == GBM_FORMAT_ARGB8888` 로 확장.

### 3. DRM framebuffer 포맷 불일치 (채널 색상 반전)

`drmModeAddFB(depth=24, bpp=32)`는 DRM에서 `XRGB8888`(byte0=B)으로 해석.
Mali 픽셀은 `[R][G][B][A]` 순서이므로 화면에서 R/B 채널이 반전됨.

→ `drmModeAddFB2(fmt=gbm_bo_get_format(bo))` 로 교체.
GBM 래퍼가 `ABGR8888`(byte0=R)을 반환하므로 DRM 포맷 디스크립터가 일치.

### 4. drmSetMaster EBADF + non-fatal 처리

`drmSetMaster(g_drm_fd)` 호출 시점에 `g_drm_fd = fd` 할당이 아직 안 됨 → EBADF.

또한 EmulationStation이 DRM master를 보유한 상태로 RetroArch를 `system()`으로
실행하면 `drmSetMaster`가 EBUSY로 실패. 기존 코드는 반환값을 무시했으나
이후 로직에서 master 없이 동작해야 함.

→ `drmSetMaster(fd)`로 수정 (올바른 fd 사용).
→ 실패 시 경고 로그 후 계속 진행 (page flip은 master 없이도 가능).

### 5. drmModeSetCrtc EACCES non-fatal 처리

ES가 DRM master 보유 중일 때 `drmModeSetCrtc`가 `EACCES`(13)를 반환.
기존 코드는 무조건 `goto error` → RetroArch 종료.

> `EACCES`와 `EPERM`은 다름: `EPERM`=1(권한 없음), `EACCES`=13(액세스 거부).
> kernel의 `DRM_IOCTL_MODE_SETCRTC`는 master 체크에서 `EACCES`를 반환.

→ `EPERM || EACCES` 모두 non-fatal로 처리, page flip으로 계속 진행.

### 6. 해상도 fallback 개선

요청 해상도 (예: 960x720) 가 DRM mode 목록에 없을 때 `modes[0]`(4K일 수 있음)으로
폴백하던 것을 현재 CRTC 모드 `g_orig_crtc->mode`(실제 출력 중인 해상도)로 변경.

## 성능 설정

### CPU/GPU 주파수 거버너 (`S95retropangui`)

부팅 시 CPU와 Mali GPU를 `performance` 거버너로 설정합니다.

```
CPU: schedutil(기본) → performance (2508 MHz 고정)
GPU: simple_ondemand(기본) → performance (852 MHz 고정)
```

`simple_ondemand`/`schedutil`은 게임 중 최저 주파수에 머무르는 경우가 있어
렌더링 지연과 오디오 끊김이 발생합니다. `performance`로 고정하면 이를 방지합니다.

> 소비 전력이 증가하지만 게이밍 OS 특성상 성능 우선.

### RetroArch 오디오 (`retroarch.cfg`)

```
audio_driver = "alsathread"   # 비블로킹 (alsa는 블로킹 → 에뮬레이션 스레드 직접 정지)
audio_latency = 64            # ms (32는 너무 작아 underrun 발생)
audio_sync = true
```

> `alsa` 드라이버는 ALSA 버퍼 처리 시 에뮬레이션 스레드가 직접 블록됨.
> `alsathread`는 별도 스레드에서 오디오 처리 → 에뮬레이션 스레드 독립.

## 테마

기본 테마: **retropangui-slate** — 독립 GitHub 레포로 관리됩니다.

- 레포: [LeonardWard/retropangui-slate](https://github.com/LeonardWard/retropangui-slate)
- 빌드 시 `post-build.sh`가 GitHub에서 자동 다운로드 → `/opt/retropangui/themes/retropangui-slate/`
- 첫 부팅 시 `S95retropangui`가 `/retropangui/share/system/emulationstation/themes/`로 복사

테마 개발은 `retropangui-slate` 레포에서 독립적으로 진행합니다.
빌드에 즉시 반영하려면 `main` 브랜치에 푸시 후 클린 빌드하거나,
기기에서 직접 파일을 교체하면 됩니다.

## EmulationStation

### 실행

```bash
SDL_VIDEODRIVER=kmsdrm MESA_LOADER_DRIVER_OVERRIDE=meson emulationstation --no-splash
```

부팅 시 `S99emulationstation` init 스크립트가 자동 실행.

### RetroArch 게임 실행 흐름

ES가 RetroArch를 `system()`으로 실행 (자식 프로세스):

```
ES (DRM master 보유)
  └─ system("/opt/retropangui/bin/retroarch -L <core> <rom>")
       ├─ drmSetMaster() → EBUSY (ES가 master 보유 중) → 경고 후 계속
       ├─ drmModeSetCrtc() → EACCES → 경고 후 계속
       └─ drmModePageFlip() → 성공 (modern kernel, auth 있으면 master 불필요)
```

> `drmModePageFlip`은 master가 아닌 authenticated fd로도 가능 (Linux kernel 5.15+).
> ES가 master를 보유하더라도 RetroArch가 page flip으로 화면 전환 가능.

### GPU 설정 (Mali-G310 / KMS DRM)

- GPU: Mali-G310 Valhall (DDK r44p0)
- DRM: `/dev/dri/card0` (aml_drm) / GPU render: `/dev/dri/renderD128`
- `MESA_LOADER_DRIVER_OVERRIDE=meson` 필수 (없으면 panfrost 로드 시도 후 크래시)
- **Amlogic DOLBY 콜백이 4K 출력을 강제함** — `odroid-drm-fbset`으로 1080p 재설정 필요

### 컨트롤러 입력 표준

RetroPangui의 입력 시스템은 RetroArch의 **RetroPad** 추상화를 기준으로 합니다.
물리 컨트롤러의 버튼을 RetroPad에 매핑하면, 각 에뮬레이터 코어가 RetroPad를 해당 시스템 컨트롤러로 변환합니다.

#### RetroPad 레이아웃 (공통 기준)

| RetroPad | Xbox 360 | DualShock 3 | 설명 |
|----------|----------|-------------|------|
| B | A | × | 주 액션 |
| A | B | ○ | 보조 액션 / 뒤로 |
| Y | X | □ | 보조 |
| X | Y | △ | 보조 |
| L1 | LB | L1 | 왼쪽 어깨 |
| R1 | RB | R1 | 오른쪽 어깨 |
| L2 | LT | L2 | 왼쪽 트리거 |
| R2 | RT | R2 | 오른쪽 트리거 |
| L3 | LS click | L3 | 왼쪽 스틱 클릭 |
| R3 | RS click | R3 | 오른쪽 스틱 클릭 |
| Select | Back | Select | 선택 / 핫키 |
| Start | Start | Start | 시작 |
| D-Pad | D-Pad | D-Pad | 방향키 |
| 왼쪽 스틱 | LS | LS | 아날로그 이동 |
| 오른쪽 스틱 | RS | RS | 아날로그 시점 |

#### 에뮬레이터별 버튼 대응

시대에 따라 없는 버튼은 가장 가까운 위치로 근사 매핑합니다.

| 에뮬 | 원본 버튼 | RetroPad 매핑 | 비고 |
|------|----------|---------------|------|
| **NES** | B, A | B, A | — |
| | Select, Start | Select, Start | — |
| **SNES** | B, A, Y, X | B, A, Y, X | — |
| | L, R | L1, R1 | — |
| **PS1** | ×, ○, □, △ | B, A, Y, X | 풀 DualShock 레이아웃 |
| | L1/R1/L2/R2 | L1/R1/L2/R2 | — |
| | L3/R3 | L3/R3 | 스틱 클릭 |
| **Genesis** | A, B, C | Y, B, A | 3버튼 → 오른쪽 정렬 |
| | X, Y, Z | X, L1, R1 | 6버튼 확장 |
| **N64** | A, B | B, Y | — |
| | C-Up/Dn/L/R | 오른쪽 스틱 | C버튼 → RS 근사 |
| | Z | L2 | — |
| | L, R | L1, R1 | — |
| **GBA** | B, A | B, A | — |
| | L, R | L1, R1 | — |

#### 지원 컨트롤러

| 컨트롤러 | 연결 | Linux FF(진동) | 비고 |
|----------|------|----------------|------|
| Xbox 360 Wireless | USB 수신기 (xpad) | ✅ | 권장 |
| DualShock 4 | USB / Bluetooth | ✅ | 권장 |
| DualShock 3 | USB / Bluetooth | ✅ | ds3drv 필요할 수 있음 |
| PS2 DS2 + USB 어댑터 | USB (0810:0001) | ❌ | 어댑터가 FF 미지원 |
| 일반 HID 패드 | USB | 장치 의존 | — |

> 진동은 Linux force feedback API(`FF_RUMBLE`)를 지원하는 컨트롤러 + 드라이버 조합에서만 동작합니다.

#### gamepad-daemon — uinput 가상 패드 시스템

`BR2_PACKAGE_GAMEPAD_MGR=y`로 빌드. `S58gamepad`가 ES/RetroArch보다 먼저 데몬을 시작.

```
[하드웨어: USB 유선 / 2.4G 동글 / Xbox 360 무선 / BT]
        ↓
[udev → /dev/input/eventX  (99-gamepad.rules 퍼미션)]
        ↓
[gamepad-daemon (S58 시작)]
  ① 데몬 시작 즉시 P1~P4 uinput 가상 장치 선점 생성 (물리 장치 연결 전)
     → udev 열거 순서상 낮은 jsN 인덱스 확보, RetroArch 인덱스 설정과 일치
  ② SDL2 GameController API로 물리 패드 정규화
  ③ SDL GUID 기반 P1~P4 슬롯 고정 (연결 순서·유무선 무관)
  ④ 재연결 시 uinput 장치 보존(phys_fd만 교체) → jsN 번호 불변
        ↓
[uinput 가상 장치 (부팅 시 선점 생성)]
  /dev/input/event? "RetroPangUI P1" (VID:5052 PID:0001)
  /dev/input/event? "RetroPangUI P2" (VID:5052 PID:0002)
  /dev/input/event? "RetroPangUI P3" (VID:5052 PID:0003)
  /dev/input/event? "RetroPangUI P4" (VID:5052 PID:0004)
  ※ FF_RUMBLE 항상 선언, virt_id→phys_id 매핑으로 물리 장치에 패스스루
  ※ 물리 장치 FF 미지원(PS2 어댑터 등)이면 패스스루 생략
        ↓
[ES (SDL2 + gamecontrollerdb.txt)]   [RetroArch (udev + autoconfig/RetroPangUI P*.cfg)]
  항상 같은 가상 장치만 봄 → P1~P4 슬롯 항상 일정

[S95retropangui (부팅 시)]
  /proc/bus/input/devices에서 RetroPangUI P1~P4의 jsN 번호 파싱
  → retroarch.cfg input_playerN_joypad_index 자동 기록
```

현장 디버깅:
```bash
gamepad-test   # 물리 패드 이벤트 실시간 확인
```

커스텀 매핑 추가 (미인식 패드):
- **ES용**: `/etc/gamepad/gamecontrollerdb.txt`에 SDL 매핑 문자열 추가
- **RetroArch용**: `/etc/retroarch/autoconfig/장치명.cfg` 추가

#### 컨트롤러별 진동(FF) 지원 현황

| 컨트롤러 | 연결 | 진동 |
|----------|------|------|
| Xbox 360 유선 | USB (xpad) | ✅ |
| Xbox 360 무선 | 수신기 (xpad wireless) | ✅ |
| DualShock 3 | USB (hid-sony) | ✅ |
| DualShock 4 | USB / BT (hid-sony) | ✅ |
| PS2 DS2 + USB 어댑터 | USB (0810:0001) | ❌ 어댑터 하드웨어 한계 |

#### 핫키 (RetroArch)

**핫키 버튼**: Select (또는 Back) — Recalbox 표준 기준

| 조합 | 기능 |
|------|------|
| 핫키 + Start | 에뮬레이터 종료 |
| 핫키 + A | RetroArch 메뉴 |
| 핫키 + B | 롬 리셋 |
| 핫키 + X | 세이브 스테이트 저장 |
| 핫키 + Y | 세이브 스테이트 로드 |
| 핫키 + D-Pad 상 | 세이브 슬롯 +1 |
| 핫키 + D-Pad 하 | 세이브 슬롯 -1 |
| 핫키 + D-Pad 우 | 빨리 감기 |
| 핫키 + D-Pad 좌 | 되감기 |

### 한글 폰트

ES FallbackFont: `/usr/bin/resources/NanumBarunGothic.ttf`

## 오디오

### 구조

```
amlogic_snd_soc (auge_sound ASoC card)
  ├── dai-link@0: TDM-B → HDMI PCM (alsaPORT-i2s2hdmi)  ← 메인 출력
  ├── dai-link@1: SPDIF-B → HDMI
  ├── dai-link@2: TDM-C → T9015 DAC (alsaPORT-i2s)
  └── dai-link@3: SPDIF
```

ALSA 기기: `hw:0,0` (pcmC0D0p) = TDM-B HDMI

### HDMI 오디오 활성화 (필수 믹서 설정)

```bash
amixer -c 0 cset name="HDMITX Audio Source Select" "Tdm_B"
amixer -c 0 cset name="Audio I2S to HDMITX Mask" 1
```

기본값(`Spdif`, `0`)으로 남으면 HDMI로 오디오 미출력.
부팅 시 `S62audio` init 스크립트가 자동으로 위 설정을 적용한다.

> **주의**: amixer에서 카드 이름 `AML-AUGESOUND`는 인식되지 않는다. 반드시 카드 번호(`0`) 또는
> short name(`AMLAUGESOUND`)을 사용해야 한다.

## 버전 관리

### RetroArch

| 패키지 | 버전 | 비고 |
|--------|------|------|
| RetroArch | `v1.22.2` | 고정 태그 + drm_ctx.c 패치 적용 |

### libretro 코어

| 시스템 | 코어 | 버전 |
|--------|------|------|
| NES | nestopia | `b0fd87d` (commit hash 고정) |
| SNES | snes9x | `1.53` |
| PSX | pcsx_rearmed | `r26l` |

버전 업데이트: `br2-external/package/libretro-cores/libretro-cores.mk`의 `_VERSION` 변수.

## 포함 패키지

| 분류 | 패키지 |
|------|--------|
| SSH / SFTP | OpenSSH (sshd + sftp-server) |
| 디스플레이 | odroid-drm-fbset, libdrm, Mesa3D (swrast + meson_dri), SDL2 (KMS/DRM) |
| GPU 드라이버 | Mali DDK r44p0 + EGL/GBM/GLES2 래퍼 |
| 오디오 | ALSA utils, amlogic-snd-codec-dummy, amlogic-snd-codec-t9015 |
| 그래픽 | OpenGL ES 3.2, EGL, Vulkan |
| mDNS | Avahi (`retropangui-c5.lan`) |
| 에뮬레이터 | RetroArch v1.22.2 + libretro 코어 (NES/SNES/PSX) |
| 프론트엔드 | EmulationStation (retropangui fork, GLES3.2/Mali-G310) |
| 번들 롬 | retrobrews NES 컬렉션 (~83종), retrobrews SNES 컬렉션 (~14종), 2048 (NES), Super-Apocalux (SNES) |

## 커널 패치 (`board/odroidc5/patches/linux/`)

### 0001 — GFX 힙 128MB 확장

S905X5M 4K 출력 시 Mali DDK가 기본 64MB GFX 힙(CMA)을 소진함.
DTS `linux,cma-default` 크기를 128MB로 증가.

### 0002 — DTV demod 컴파일 에러

`amlfrontend.c`가 `DTV_BLIND_SCAN_STEP_NEXT`를 참조하지만 `aml_fe_ext.h`에
정의가 없어 컴파일 실패. 상수(`= 117`)와 `AML_DTV_MAX_COMMAND` 갱신을 추가.

~~### 0003 — Mali hwcnt `mcu_on` 상태 누수~~ *(비활성, `patches/_disabled/` 참고)*

~~### 0004 — Mali PM 정책 `coarse_demand` 전환~~ *(비활성, `patches/_disabled/` 참고)*

> **배경**: 2026-04-29 Hardkernel `common_drivers` 업스트림이 Mali DDK를 r44p1 → r54p1으로
> 업그레이드했으나 동봉 firmware(ba6471e)는 r44p1 전용이라 글로벌 요청 2100ms 타임아웃이 발생.
> 패치 0003·0004는 이를 우회하려던 시도였으나, r54p1 호환 firmware가 ARM 상용 라이선스여서
> 오픈소스에 포함 불가. `buildroot/internal_build.sh`에서 `common_drivers`를 r44p1 마지막
> 커밋(`8f02b4a0ec2e`)으로 고정하여 근본 해결.

## 알려진 사항

- initramfs 없음 → `root=UUID=...` 사용 불가, `/dev/mmcblk${devnum}p2` 직접 지정 (U-Boot 런타임 치환)
- odroid-drm-fbset은 Hardkernel 공식 Ubuntu 이미지에서 복사한 바이너리
- SoC 정식 명칭: S905X5M (S7D 계열), DTS: `s7d_s905x5m_odroidc5`
- Mali-G310 Panfrost(오픈소스) 드라이버 미지원 → 전용 Mali DDK 사용
  (Mesa3D에서 panfrost 제거, swrast 유지)
- ES에서 RetroArch 실행 시 DRM master를 ES가 보유함 → SetCrtc EACCES는 정상 동작
- RetroArch 화면 출력은 page flip으로 이루어짐 (SetCrtc 없이도 작동)
- `mDNS` 접속 주소: `retropangui-c5.lan` (Avahi)
- VLC MP3 코덱 미포함 → ES 배경음악 미지원

## 타겟 하드웨어

| 항목 | 값 |
|------|-----|
| 보드 | Odroid C5 |
| SoC | Amlogic S905X5M (ARM Cortex-A55 × 4, 최대 2.508 GHz) |
| GPU | Mali-G310 Valhall (최대 852 MHz) |
| 아키텍처 | aarch64 |
| Buildroot | 2024.02.1 |
| 커널 | Hardkernel odroids7d-5.15.y |
