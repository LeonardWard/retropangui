# Changelog

All notable changes to RetroPangui are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [0.4] — 2026-05-24

### Added

- **retropangui-slate 테마 (독립 레포)**

  EmulationStation 기본 테마를 별도 GitHub 레포로 분리.
  디자인 컨셉: 다크 네이비 사이드바 + 밝은 그레이 메인 영역 + 블루 액센트, Pretendard 폰트(한글+라틴).

  - 레포: `https://github.com/LeonardWard/retropangui-slate`
  - 포함 에셋: Pretendard 폰트(v1.3.9), 시스템 SVG 로고 119종, 콘솔 아트 PNG 110종
  - 지원 뷰: `system` (수직 캐러셀 + 콘솔 아트), `detailed` (3컬럼 텍스트리스트), `video`, `grid`, `basic`
  - 20개 시스템별 한글 설명 및 연도·제조사 정보 포함

- **빌드 시 테마 자동 다운로드**

  `post-build.sh`가 GitHub 아카이브(`/archive/refs/heads/main.tar.gz`)를 wget으로 받아
  `/opt/retropangui/themes/retropangui-slate/`에 설치. 첫 부팅 시 `S95retropangui`가
  `/retropangui/share/system/emulationstation/themes/`로 복사.

- **git shallow clone 전면 적용 (빌드 속도 개선)**

  Buildroot git 다운로더가 기본적으로 전체 히스토리를 fetch하는 문제를 패치.
  `internal_build.sh`에서 `buildroot/support/download/git` 파일을 Python으로 실시간 수정해
  `BR2_GIT_FETCH_DEPTH=1` 환경변수를 `--depth` 옵션으로 주입.
  대형 git 패키지(uboot, kodi, retroarch, emulationstation)는 `build.sh`의 `_shallow_clone()`으로
  Docker 실행 전 `dl/` 캐시에 미리 받아 OOM 및 반복 clone 방지.

### Fixed

- **post-build.sh: 테마 복사 경로 수정**

  `retropangui-slate` GitHub 레포 폴더 구조 재정리(`git mv`로 파일을 레포 루트로 이동) 후
  `post-build.sh`의 tar.gz 추출 경로가 맞지 않던 문제 수정.
  `retropangui-slate-main/retropangui-slate/` (없는 하위 폴더) →
  `retropangui-slate-main/`을 통째로 `retropangui-slate`로 복사하도록 변경.

- **es_input.cfg: 키보드 Enter/Escape 역할 교체**

  키보드 매핑에서 `"a"`(확인)과 `"b"`(취소) 키 ID가 반전돼 있던 문제 수정.
  - `"a"` (확인): Escape → Enter (id=13)
  - `"b"` (취소): Enter → Escape (id=27)

### Removed

- **themes/ 폴더 삭제**

  `retropangui-slate` 테마를 독립 레포로 분리함에 따라
  메인 레포의 `themes/` 디렉토리 제거. 빌드 시 GitHub에서 자동 다운로드.

---

## [0.3] — 2026-05-21

### Fixed

- **RetroArch linuxraw 드라이버 활성화 (openvt VT 할당)**

  ES가 `nohup sh -c '...'` 안에서 실행되어 ctty=0(controlling terminal 없음) 상태였고,
  RetroArch의 linuxraw 드라이버는 `KDSKBMODE` 적용을 위해 VT 필수라 항상 udev로 폴백했다.
  udev 드라이버는 sysfs 경로 정렬 특성상 물리 패드를 index 0으로 열거해 Port 1에 Xbox가 붙었다.

  **수정**: `S99emulationstation`에서 `openvt -c 1 -s -w --`로 ES/RA에 tty1 할당.
  linuxraw 활성화 → jsX 순서 기반 열거 → Port 1 = RetroPangUI P1.

- **xpad 로드 순서 제어로 vdev jsX 선점 보장 (CONFIG_JOYSTICK_XPAD=m)**

  xpad가 built-in(=y)이면 커널 부팅 시 Xbox 컨트롤러가 js0을 선점해 vdev가 js1~js4로 밀렸다.

  **수정**: `linux-ksmbd.config`에 `CONFIG_JOYSTICK_XPAD=m` 설정.
  `S58gamepad`에서 vdev 생성 완료(`RetroPangUI P1` 감지) 후 `modprobe xpad` 실행.

- **S95retropangui: vdev jsX 번호 동적 탐색**

  물리 컨트롤러가 부팅 시 연결돼 있거나 js 번호가 재활용되면 vdev 번호가 가변적이었다.
  기존 `input_player1_joypad_index = "0"` 하드코딩으로는 대응 불가.

  **수정**: `/sys/class/input/jsX/device/name`으로 vdev 이름 탐색 후 실제 번호 기록.

- **RA autoconfig linuxraw 전환 + d-pad 축 매핑 수정**

  autoconfig에 `input_driver = "udev"`가 남아있어 linuxraw 환경에서 매핑이 무시됐다.
  d-pad가 HAT 표기(`h0up`)로 되어있어 linuxraw에서 동작하지 않았다.

  **수정**: 전 패드(P1~P4) `input_driver = "linuxraw"` 변경,
  d-pad를 axis 표기(`-7`/`+7`/`-6`/`+6`)로 변경 (joydev ABS_HAT0X/Y → axis 6/7).

- **gamepad_daemon: find_phys_evdev Xbox 수신기/컨트롤러 구분**

  Xbox 무선 수신기와 컨트롤러 슬롯이 동일 VID:PID를 가져 수신기가 먼저 선택됐다.
  수신기는 EV_ABS 없어 `EVIOCGRAB` ENODEV 반환.

  **수정**: SDL이 열어놓은 fd와 `st_rdev` 매칭 우선, 없으면 EV_ABS 보유 장치만 후보로 선택.

- **modprobe.d/xpad.conf: udev auto-load 차단**

  udev가 Xbox 연결 시 modalias로 xpad를 자동 로드하는 것을 방지.
  S58gamepad의 수동 `modprobe xpad` 호출은 blacklist 무관하게 정상 동작.

### Changed

- **fetch-blobs.sh: Mali DDK 소스를 meta-odroid-aml Yocto 레이어로 변경**

  기존 Hardkernel apt/CDN 서버(`dn.odroid.com`)는 Cloudflare 봇 차단으로 자동 다운로드 불가.
  Hardkernel 공식 Yocto 레이어(`github.com/mdrjr/meta-odroid-aml`) master 브랜치의
  `tarball.tar.bin`(~100MB)에서 Mali DDK를 추출.

- **build.sh: `v` 접두사 제거 코드 삭제**

  태그 정책을 `v0.x` → `0.x`로 변경했으므로 `VERSION="${VERSION#v}"` 불필요.

---

## [0.2] — 2026-05-17

### Fixed

- **ES 이중 입력 수정 (gamepad-daemon: 물리 패드 없는 슬롯 무시)**

  Twin USB Joystick(2포트)을 연결하면 SDL이 내부적으로 4개의 조이스틱 이벤트를 발생시켜
  슬롯 2·3(P3·P4)에 할당된 가상 패드에도 입력이 전달됐다. EmulationStation에서 메뉴 이동 시
  하나의 물리 입력이 여러 번 처리되는 이중 입력 현상 발생.

  **수정**: `gamepad_daemon.c` 메인루프에 `if (g_phys_fd[slot] < 0) continue;` 게이트 추가.
  물리 패드가 연결되지 않은 슬롯은 가상 패드로 이벤트를 전달하지 않는다.

- **RetroArch Port 1 패드 오할당 수정 (S95retropangui: -1 rotation 보정)**

  RetroArch는 udev inotify로 입력 장치를 열거하다가 SDL이 첫 번째 가상 패드(가장 낮은
  event 번호, P1)를 open할 때 발생하는 udev change 이벤트를 감지해 P1을 장치 목록 맨 끝으로
  재배치한다. 결과적으로 evdev 스캔 순서(P1=rank 0)와 RA 내부 인덱스가 -1씩 어긋났다.

  **수정**: `S95retropangui`의 joypad_index 계산에 `-1 rotation` 보정 공식 적용.
  ```
  ra_virt_rank = (evdev_virt_rank - 1 + num_virt) % num_virt
  idx = num_phys + ra_virt_rank
  ```
  물리 패드 2개(Twin USB) + 가상 패드 4개 환경에서 결과: P1→idx 5, P2→idx 2, P3→idx 3, P4→idx 4.
  RetroArch Port 1이 RetroPangUI P1을 올바르게 선택함을 확인.

- **gamepad-daemon: EVIOCGRAB EBUSY 수정 (st_rdev 중복 방지)**

  `find_phys_evdev()`가 같은 VID+PID를 가진 장치 중 이미 다른 슬롯에 할당된 것을 다시 열고
  `EVIOCGRAB`을 시도해 EBUSY 오류 발생. 동일한 USB 허브에 같은 모델 컨트롤러가 여러 개
  연결된 경우에도 재현.

  **수정**: `g_phys_fd`에 이미 열려있는 fd의 `st_rdev`를 수집해 중복 장치를 건너뜀.

- **S58gamepad: SDL_JOYSTICK_HIDAPI=0 설정 추가**

  SDL의 HIDAPI 드라이버가 일부 장치를 가로채 evdev와의 충돌을 일으키는 문제 방지.
  데몬 실행 전 `SDL_JOYSTICK_HIDAPI=0`을 환경변수로 설정.

- **scripts/fetch-blobs.sh: Hardkernel apt URL 수정**

  Mali DDK deb 패키지 주소가 변경됨에 따라 URL을
  `https://dn.odroid.com/ubuntu/ubuntu24` → `https://dn.odroid.com/S905X5M/ODROID-C5/Ubuntu`로 갱신.

### Added

- **부분 빌드 옵션 (`--partial` / `-p`)**

  `build.sh`에 `--partial` 옵션 추가. gamepad-mgr 소스 수정 후 전체 Buildroot 재빌드 없이
  board 파일 동기화 + gamepad-mgr 재빌드 + 이미지 재패킹만 수행. 빌드 시간을 대폭 단축.

  ```bash
  ./build.sh --partial
  ./build.sh odroidc5 --partial
  ```

- **build.sh: 버전 Git 태그 자동 인식**

  `VERSION` 환경변수가 없으면 `git describe --tags --always`로 버전을 자동 결정.
  태그 `v0.2`를 달면 이미지 파일명이 `retropangui-odroidc5-0.2.img`로 자동 결정.

---

## [0.2] — 2026-05-16

### Fixed

- **오디오 무음 버그 수정: S62audio CARD 이름 불일치 + `Audio I2S to HDMITX Mask` 누락**

  `S62audio`에서 `CARD="AML-AUGESOUND"`로 설정했으나 amixer는 이 이름을 인식하지 못해
  ("Invalid card number") 스크립트 전체가 조기 종료됐다. 결과적으로 HDMI 오디오 경로
  (`HDMITX Audio Source Select`, `Audio I2S to HDMITX Mask` 등) 설정이 전혀 적용되지 않음.

  클린 빌드 전에는 디바이스에 수동 설정 값이 남아있어 증상이 가려져 있었으나,
  새 이미지 플래싱 후 기본값(Spdif, Mask=0)으로 초기화되면서 무음 재현.

  **수정**:
  - `CARD=0`으로 변경 (카드 번호 사용).
  - `Audio I2S to HDMITX Mask = 1` 설정 추가 (HDMI 수신단 I2S 신호 활성화).

---

## [0.2] — 2026-05-15

### Fixed

- **Mali GPU 초기화 실패 (2100ms 타임아웃) 근본 원인 수정**

  2026-04-29 Hardkernel `common_drivers` 업스트림 커밋(`6e52ffa`)이 Mali 커널 드라이버 DDK를
  **r44p1 → r54p1**로 업그레이드했다. 그런데 동봉된 firmware(`mali_csffw.bin`, SHA `ba6471e`,
  Hardkernel Ubuntu 24.04 이미지에서 추출)는 r44p1용이라 r54p1과 호환되지 않아
  `kbase_csf_firmware_load_init()` 내 `global_init_on_boot()` 단계에서 GLB_REQ_CFG_MASK
  ACK를 받지 못하고 2100ms(600M cycles / 285MHz) 타임아웃이 발생했다.

  r54p1 호환 firmware는 ARM 상용 라이선스로 배포되어 오픈소스 프로젝트에 포함 불가.

  **수정**: `buildroot/internal_build.sh`에서 `common_drivers`를 r44p1이 마지막으로
  존재했던 커밋(`8f02b4a0ec2e`, `odroids7d-5.15.y` 브랜치 기준)으로 고정.
  `--depth=15` shallow clone 후 해당 SHA로 checkout.

- **빌드 시스템: board/ 동기화 누락 수정**

  `internal_build.sh`가 `cp -r /home/builder/board/${DEVICE}/* board/${DEVICE}/`로
  호스트 board 디렉토리를 buildroot 내부로 복사할 때, 호스트에서 삭제된 파일이
  buildroot 내부에 남아있는 문제 수정. `cp -r` → `rsync -a --delete`로 변경.
  패치 파일 삭제가 빌드에 즉시 반영되지 않아 컴파일 에러를 디버깅하는 데 시간을 소모함.

### Removed

- **패치 0003 — Mali hwcnt `mcu_on` 상태 누수 수정**: r54p1 DDK에서만 나타나는 현상.
  r44p1 롤백으로 불필요. `board/odroidc5/patches/_disabled/`로 이동.

- **패치 0004 — Mali PM 정책 `coarse_demand` 전환**: r54p1 + r44p1 firmware
  불호환으로 인한 타임아웃을 우회하려던 패치. 롤백으로 불필요. 동일 경로로 이동.

---

## [0.1] — 2026-05-13

### Changed
- **프로젝트 소스 폴더명 변경**: `c5-pangui/` → `retropangui-c5/`
- **호스트명 · mDNS · Samba 이름 변경**: `c5-pangui` → `retropangui-c5`. 접속 주소 `retropangui-c5.lan`. `smb.conf`의 `netbios name` / `server string`, 두 defconfig의 `BR2_TARGET_GENERIC_HOSTNAME` / `BR2_TARGET_GENERIC_ISSUE`, `post-build.sh` hostname 및 `/etc/network/interfaces`, boot 레이블 일괄 변경.
- **Share 마운트 경로 재구조화**: 마운트 포인트 `/share` → `/retropangui/share`로 변경하고 내부 `/retropangui/` 서브디렉토리 제거. 결과 경로: `/retropangui/share/roms/`, `/retropangui/share/system/retroarch/` 등. `S61share`, `retroarch.cfg`, `apply_retropangui_conf.sh`, `S95retropangui`, `smb.conf`, `post-build.sh` 일괄 수정.

### Fixed
- **gamepad-daemon: FF(진동) ID 매핑 수정**: `UI_FF_UPLOAD` 시 가상 장치의 `effect.id`(virt_id)를 그대로 `EVIOCSFF(phys_fd)`에 전달하던 버그 수정. 물리 장치가 이를 "슬롯 N 업데이트"로 해석해 EINVAL 반환 → RetroArch가 진동 effect를 전송하지 못하던 문제. 수정: `ff_id_map[FF_MAX_EFFECTS]` 배열로 virt_id→phys_id 매핑 관리, 신규 업로드 시 `effect.id = -1`로 강제해 물리 장치가 새 슬롯을 할당하게 함.
- **gamepad-daemon: 부팅 시 uinput 가상 장치 선점 생성**: 물리 장치 연결 전(`gp_init()` 호출 전)에 P1~P4 가상 장치를 먼저 생성. udev 열거 순서상 가상 장치가 낮은 jsN 인덱스를 확보해 RetroArch `input_playerN_joypad_index` 설정과 일치.
- **gamepad-daemon: 재연결 시 uinput 장치 보존**: 물리 패드 재연결 시 기존 uinput 장치를 파괴/재생성하지 않고 `gp_vdev_rebind_phys()`로 `phys_fd`만 교체. udev 열거 번호가 유지되어 RetroArch 인덱스 틀어짐 방지.
- **S95retropangui: 부팅마다 joypad 인덱스 자동 감지**: `/proc/bus/input/devices`에서 `RetroPangUI P1~P4`의 `jsN` 번호를 파싱해 `retroarch.cfg`의 `input_playerN_joypad_index`에 매 부팅마다 기록. Xbox 360 등 외부 장치가 먼저 열거돼 인덱스가 밀리는 문제 해결.
- **es_settings.cfg 초기화 수정**: 빈 파일 생성(`touch`) 대신 XML 골격(`<?xml version="1.0"?><config></config>`) 생성. EmulationStation(pugixml)이 빈 파일에서 "No document element found" 파싱 오류를 내던 문제 수정.
- **apply_retropangui_conf.sh 경로 및 XML 수정**: `RETROARCH_CFG`, `ES_SETTINGS_CFG` 경로가 `/share/system/`을 잘못 참조하던 문제를 `/retropangui/share/system/`으로 수정. `es_set()` 함수의 XML 삽입 방식도 `</config>` 태그 앞에 올바르게 삽입하도록 수정.
- **S58gamepad: 데몬 로그 추가**: 데몬 stdout/stderr를 `/var/log/gamepad.log`로 리디렉션.

---

## [0.1] — 2026-05-11

### Added
- **Multi-device build system**: `build.sh` now accepts a positional `DEVICE` argument (e.g. `./build.sh odroidc5`); falls back to `DEVICE` env var, default `odroidc5`. Validates defconfig and board directory existence before entering Docker, and prints supported device list on invalid input. Output image renamed to `retropangui-<device>-<version>.img`.
- **Project rename — RetroPangui**: Project brand changed from C5-PANGUI to RetroPangui. defconfig renamed `retropangui-odroidc5_defconfig`; Docker image tag changed to `retropangui-builder`; `os-release` NAME/ID updated to `retropangui`; `retropangui-version` replaces `c5-pangui-version` in rootfs.
- **Share directory namespacing**: All user data on the exFAT partition moved under a dedicated namespace — `roms/`, `bios/`, `saves/states/`, `screenshots/`, `music/`, `system/retroarch/`, `system/emulationstation/`. Mount point later corrected to `/retropangui/share` (see 2026-05-13). Prevents collision when multiple OSes share the same SD card in the future.
- **exFAT volume label lowercase**: `mkfs.exfat -n "share"` (was `"SHARE"`) — exFAT supports mixed case; lowercase matches the internal mount point name.
- **gamepad-mgr**: SDL2 기반 게임패드 슬롯 매니저 라이브러리 추가. Player 1~4 슬롯 고정 할당, SDL GUID 기반 재연결 시 동일 슬롯 복원, SDL GameController API (자동 매핑) / raw 조이스틱 폴백 통합, 상태 폴링 + 이벤트 콜백 양쪽 지원. `99-gamepad.rules`로 `/dev/input/js*`, `/dev/input/event*` 퍼미션 설정. `gamepad_config.json`에 PS2 USB 어댑터(0810:0001) SDL 매핑 포함. `/usr/bin/gamepad-test`로 현장 디버깅 가능.
- **gamepad-daemon (uinput 가상 패드)**: 물리 컨트롤러를 Player 1~4 가상 장치로 정규화하는 데몬 추가. `S58gamepad` init 스크립트로 ES/RetroArch보다 먼저 시작. 핵심 기능: ① SDL GUID 기반 슬롯 고정 — 연결 순서나 유/무선 혼재 무관하게 P1~P4 유지, ② uinput으로 `/dev/input/eventX` 가상 장치 생성 — ES(SDL2), RetroArch(udev 드라이버) 양쪽 투명 인식, ③ FF 패스스루 — 물리 장치가 `FF_RUMBLE` 지원 시 가상 장치에도 FF 선언 후 ioctl 경유 물리 장치로 전달(DS3/DS4/Xbox 360 진동 작동, PS2 어댑터는 하드웨어 한계로 미지원), ④ 125Hz 폴링 루프.
- **gamecontrollerdb.txt**: `/etc/gamepad/gamecontrollerdb.txt` 추가. ES 시작 시 `SDL_GAMECONTROLLERCONFIG_FILE` 환경변수로 자동 로드. PS2 어댑터(0810:0001) 3종 버전 GUID 매핑 및 가상 패드 P1~P4 매핑 포함.
- **RetroArch autoconfig**: `/etc/retroarch/autoconfig/` 추가. `RetroPangUI P1~P4.cfg` — 가상 패드 udev 버튼/축 매핑(BTN_SOUTH=304 등). `PS2 USB Adapter.cfg` — 데몬 없이 직접 연결 시 임시 대응. `retroarch.cfg`에 `joypad_autoconfig_dir` 추가.
- **PCSX-ReARMed DualShock 기본값**: `retroarch-core-options.cfg` 템플릿 추가. `pcsx_rearmed_pad1~4type=dualshock`, `pcsx_rearmed_vibration=enabled` — PS1 게임 실행 시 아날로그 스틱과 진동이 기본 활성화됨. `retroarch.cfg`에 `core_options_path` 추가; 첫 부팅 시 `S95retropangui`가 `/share`로 복사.

## [0.1] — 2026-05-01

### Fixed
- **boot.cmd / boot.ini**: Hardcoded `root=/dev/mmcblk1p2` and `fatload mmc 1:1` replaced with `${devnum}` — U-Boot substitutes at runtime (SD=1, eMMC=0), enabling eMMC boot without kernel panic
- **extlinux.conf**: Removed from boot partition — `${devnum}` substitution not possible in extlinux format; `boot.scr` handles SD/eMMC dynamically and is sufficient
- **S61share**: Device path `/dev/mmcblk1` replaced with dynamic detection via `/proc/mounts` (`awk`) — `findmnt` (util-linux) is not present in the image; share partition creation and mounting now works on both SD card and eMMC
- **S61share**: Added `partprobe` after `fdisk`, double `sync`, and `sleep 3` before reboot to prevent partition table loss on fast reboot
- **S60display**: Removed `-daemon` and `&` flags from `odroid-drm-fbset` — display init now runs in foreground and exits, releasing DRM master before EmulationStation starts
- **S99emulationstation**: Replaced fragile `sleep 2` with `/dev/dri/card0` readiness check to eliminate race condition between display init and ES startup
- **RetroArch**: `video_scale_integer` default changed from `true` to `false` — game screen now fills display proportionally instead of showing a reduced integer-scaled window

### Added
- **NTP / fake-hwclock**: `openntpd` added to defconfig; `S49ntp` init script implements fake-hwclock pattern — saves time on shutdown, restores on boot (fallback: 2026-05-01) to prevent epoch (1970) boot. OpenNTPD 6.8p1 deprecates `-s` and lacks libtls for `constraints`, so fake-hwclock is the only viable approach without RTC. ntpd starts after DHCP (background wait, up to 60s) for fine-grained precision sync.
- **Timezone**: `BR2_TARGET_TZ_INFO=y` + `BR2_TARGET_LOCALTIME="Asia/Seoul"` added to defconfig — installs zoneinfo and sets `/etc/localtime` to KST (UTC+9) at build time
- **HDMI hotplug recovery**: udev rule `70-hdmi-hotplug.rules` + `/usr/sbin/hdmi-hotplug` — Amlogic HDMI driver disables PHY on HPD LOW but does not re-enable on HPD HIGH; ES (SDL2 KMSDRM) survives the disconnect without crashing; script writes `1` to `/sys/class/amhdmitx/amhdmitx0/phy` on reconnect to restore signal with no ES restart and no game state loss. S99 also enables PHY before each ES start to handle cold-boot edge cases
- **S99emulationstation**: Added HPD wait at restart loop top (waits up to 60s for HDMI before initializing DRM) and PHY enable before `odroid-drm-fbset`; loop no longer `break`s on unexpected ES exit — always restarts to handle crashes

### Removed
- **OpenSSH**: Removed `BR2_PACKAGE_OPENSSH` from defconfig — Dropbear is sufficient for embedded SSH access; having both caused `S50sshd` and `S50dropbear` to conflict on port 22

### Added
- **JOYSTICK_XPAD_FF**: `CONFIG_JOYSTICK_XPAD_FF=y` added to `linux-ksmbd.config` — enables force feedback (rumble) for Xbox 360 wired/wireless controllers via kernel xpad driver; previously `JOYSTICK_XPAD=y` was built-in but FF support was disabled, causing `/sys/class/input/inputX/capabilities/ff=0`

### Known Issues
- Save file folder structure uses core name instead of ROM system name (RetroArch config pending)
- **PS2 USB 어댑터 다종 대응 미완**: PS2 USB 어댑터는 제조사·칩셋에 따라 VID/PID와 장치 이름이 모두 다름. 현재 `gamecontrollerdb.txt`는 DragonRise(0810:0001) 3종 버전만 포함. `autoconfig/PS2 USB Adapter.cfg`의 `input_device` 값도 실제 연결 장치 이름과 일치 여부 확인 필요. 해결 방법: 타겟에서 `cat /proc/bus/input/devices`로 실제 이름과 VID/PID 확인 후 각 어댑터별 파일 추가.
- **Xbox 360 무선 연결 미검증**: xpad 드라이버는 활성화돼 있으나 무선 수신기 + 컨트롤러 페어링이 실제로 동작하는지 미확인. `dmesg | grep xpad`로 수신기 인식 여부 확인 필요.
- **Controller input system (구 이슈, 해결 완료)**: gamepad-daemon으로 슬롯 고정 및 FF 패스스루 구현됨. PCSX-ReARMed pad type/vibration은 `retroarch-core-options.cfg` 기본값으로 설정 완료.

---

## [0.1] — 2026-04-26

### Added
- Initial release: Buildroot-based retro gaming OS for Odroid C5 (Amlogic S905X5M, Mali-G310 Valhall r44p0)
- EmulationStation frontend with nostalgia-pure-lite-ko theme
- RetroArch v1.22.2 with NES (Nestopia), SNES (Snes9x), PS1 (PCSX-ReARMed), DOS (DOSBox Pure), ScummVM cores
- Kodi 21.3 (Omega) GBM/GLES2 build for KMS/DRM
- Mali-G310 EGL/GBM wrapper (format conversion XRGB→ABGR, AFBC modifier support)
- SDL2 KMSDRM patch: `drmModeAddFB2` with `DRM_FORMAT_ABGR8888` for correct channel order on Mali Valhall
- RetroArch `drm_ctx.c` patch: 6 fixes for DRM master ownership, EBADF/EACCES handling, format mismatch, mode fallback to current CRTC (prevents 4K fallback causing stutter)
- HDMI audio via ALSA `AML-AUGESOUND` (TDM-B → HDMITX path, `S62audio` init script)
- SMB3 file sharing via ksmbd
- mDNS hostname resolution (`hostname.local`) via avahi
- `/share` exFAT partition auto-creation and mounting
- CPU/GPU performance governor forced at boot (`S95retropangui`)
