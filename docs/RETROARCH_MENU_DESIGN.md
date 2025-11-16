# RetroArch 설정 메뉴 통합 기획문서

**작성일**: 2025-11-09
**상태**: 초안
**목적**: EmulationStation 메뉴를 통한 RetroArch 설정 통합 관리

---

## 📋 목차

1. [프로젝트 개요](#프로젝트-개요)
2. [현재 상황 분석](#현재-상황-분석)
3. [설정 계층 구조](#설정-계층-구조)
4. [UI/UX 설계](#uiux-설계)
5. [기술 스택 및 구현 방식](#기술-스택-및-구현-방식)
6. [파일 구조](#파일-구조)
7. [개발 단계](#개발-단계)
8. [참고 사항](#참고-사항)

---

## 프로젝트 개요

### 목적
EmulationStation(ES) 메뉴를 통해 RetroArch의 **전역, 시스템별, 게임별 설정**을 통합 관리할 수 있는 UI 제공.

### 핵심 요구사항
- ES 메뉴에서 RetroArch 설정 항목 접근
- 설정 계층 구조 지원: 게임별 > 시스템별 > 글로벌
- 설정 변경사항 즉시 적용 및 영구 저장
- 사용자 친화적 UI/UX

---

## 현재 상황 분석

### ES 메뉴 구조
```
MAIN MENU (GuiMenu.cpp)
├── SCRAPER
├── SOUND SETTINGS
├── UI SETTINGS
├── EMULATOR SETTINGS          ← 기존: 코어 선택만 가능
├── GAME COLLECTION SETTINGS
├── OTHER SETTINGS
├── CONFIGURE INPUT
└── QUIT
```

**주요 발견사항:**
- `GuiMenu::openEmulatorSettings()`: 시스템별 기본 코어 선택 기능만 존재 (GuiMenu.cpp:744~827)
- `GuiSettings` 클래스: 설정 화면 구성용 컴포넌트
- XML 업데이트: bash 스크립트 호출 방식 (`es_systems_updater.sh`)
- 설정 저장: `Settings::getInstance()->set*()` 패턴 사용

### RetroArch 설정 파일 구조 분석 (2025-11-09)

#### 설정 파일 위치
```bash
# config.sh에서 정의된 경로 (67~71번 줄)
RA_CONFIG_PATH="$USER_CONFIG_PATH/retroarch"
  → 실제 경로: /home/pangui/share/system/configs/retroarch

RA_CONFIG_DIR="$USER_HOME/.config/retroarch"
  → 실제 경로: /home/pangui/.config/retroarch (심볼릭 링크)

# RetroArch 설정 파일
GLOBAL_CONFIG: /home/pangui/.config/retroarch/retroarch.cfg
SKELETON: /opt/retropangui/etc/retroarch.cfg
TEMPLATE: /home/pangui/scripts/retropangui/resources/retroarch.init.cfg
```

#### 설치 시 처리 방식 (retroarch.sh:48~66)
```bash
1. RA_CONFIG_PATH 디렉토리 생성 (share/system/configs/retroarch)
2. 기존 RA_CONFIG_DIR 제거
3. 심볼릭 링크 생성: ~/.config/retroarch → share/system/configs/retroarch
4. skeleton 파일 복사: /opt/retropangui/etc/retroarch.cfg → RA_CONFIG_PATH/retroarch.cfg
```

**중요 발견:**
- 현재 `retroarch.cfg`는 skeleton 파일 (대부분 주석 처리)
- RetroArch 실행 시 자동으로 값 추가/업데이트
- `resources/retroarch.init.cfg`: 3362줄, 모든 설정 항목 정의 (기본값 포함)

#### RetroArch 설정 파일 적용 우선순위

```
1. 게임별 설정:     [ROM 경로]/[게임명].cfg        (최우선)
2. 시스템별 설정:   [시스템 경로]/retroarch.cfg   (중간)
3. 글로벌 설정:     ~/.config/retroarch/retroarch.cfg (기본)
4. 스켈레톤 설정:   /opt/retropangui/etc/retroarch.cfg (초기값)
```

#### 설정 파일 형식
```ini
# resources/retroarch.init.cfg 샘플 (1~50줄)
accessibility_enable = "false"
audio_enable = "true"
audio_driver = "alsa"
audio_latency = "64"
audio_sync = "true"
video_fullscreen = "true"  # 추정
video_vsync = "true"       # 추정
...
```

**특징:**
- key = "value" 형식
- boolean: `"true"` / `"false"` (문자열)
- 숫자: `"64"`, `"0.0"` (문자열)
- 경로: `"~/.config/retroarch/assets"` (틸드 지원)

---

## 설정 계층 구조

### 1단계: 전역(글로벌) 설정
**위치**: `~/.config/retroarch/retroarch.cfg`

**노출할 주요 설정 항목** (우선순위 높은 순):
```ini
# 비디오 설정
video_fullscreen = "true"
video_windowed_fullscreen = "true"
video_smooth = "true"
video_threaded = "true"
video_vsync = "true"
video_aspect_ratio_auto = "true"
video_scale_integer = "false"

# 오디오 설정
audio_enable = "true"
audio_sync = "true"
audio_latency = "64"

# 입력 설정
input_autodetect_enable = "true"
input_joypad_driver = "udev"

# 저장 설정
savestate_auto_save = "false"
savestate_auto_load = "false"
save_file_compression = "true"

# 기타
rewind_enable = "false"
fastforward_ratio = "0.0"
pause_nonactive = "true"
```

### 2단계: 시스템별 설정 (향후)
**위치**: `/home/pangui/share/system/configs/[system]/retroarch.cfg`

시스템 특성에 맞는 오버라이드 설정
- 예: PSX → `video_scale_integer = false`
- 예: NES → `video_scale_integer = true`

### 3단계: 게임별 설정 (향후)
**위치**: `/home/pangui/share/roms/[system]/[game].cfg`

개별 게임 최적화 설정

---

## UI/UX 설계

### 메뉴 배치 방안 (결정 필요)

#### 옵션 A: EMULATOR SETTINGS 안에 통합
```
EMULATOR SETTINGS
├── [시스템1] DEFAULT EMULATOR
├── [시스템2] DEFAULT EMULATOR
├── ...
└── RETROARCH SETTINGS          ← 새로 추가
    ├── Video Settings
    ├── Audio Settings
    ├── Input Settings
    ├── Saving Settings
    └── Other Settings
```
**장점**: 에뮬레이터 관련 설정이 한 곳에 모임
**단점**: 메뉴 깊이 증가

#### 옵션 B: 별도 메뉴 항목
```
MAIN MENU
├── ...
├── EMULATOR SETTINGS
├── RETROARCH SETTINGS          ← 새로 추가 (별도 메뉴)
├── GAME COLLECTION SETTINGS
├── ...
```
**장점**: 접근성 좋음, 독립적 관리
**단점**: 메인 메뉴 항목 증가

#### 옵션 C: OTHER SETTINGS 안에 추가
```
OTHER SETTINGS
├── [기존 항목들]
└── RETROARCH SETTINGS          ← 새로 추가
```
**장점**: 메인 메뉴 깔끔
**단점**: 찾기 어려움

**→ 결정 대기: 사용자 선택 필요**

### 설정 화면 구조 (1단계)

```
RETROARCH SETTINGS
│
├── Video Settings
│   ├── Fullscreen              [ON/OFF]
│   ├── VSync                   [ON/OFF]
│   ├── Smooth Video            [ON/OFF]
│   ├── Threaded Video          [ON/OFF]
│   └── Integer Scale           [ON/OFF]
│
├── Audio Settings
│   ├── Audio Enable            [ON/OFF]
│   ├── Audio Sync              [ON/OFF]
│   └── Audio Latency           [32/64/128/256 ms]
│
├── Saving Settings
│   ├── Auto Save State         [ON/OFF]
│   ├── Auto Load State         [ON/OFF]
│   └── Compress Saves          [ON/OFF]
│
└── Other Settings
    ├── Rewind                  [ON/OFF]
    ├── Fast Forward Ratio      [0.0/2.0/4.0/8.0]
    └── Pause When Inactive     [ON/OFF]
```

---

## 기술 스택 및 구현 방식

### 1. C++ (EmulationStation 수정)

#### 수정 대상 파일
```
/home/pangui/scripts/retropangui-emulationstation/
├── es-app/src/guis/
│   ├── GuiMenu.h               # 메뉴 선언 추가
│   ├── GuiMenu.cpp             # openRetroArchSettings() 함수 추가
│   └── GuiRetroArchSettings.h  # 새 파일: RetroArch 설정 전용 GUI
│   └── GuiRetroArchSettings.cpp # 새 파일: 설정 화면 구현
```

#### 주요 구현 클래스/함수
- `GuiRetroArchSettings`: RetroArch 설정 전용 GUI 클래스
- `GuiMenu::openRetroArchSettings()`: 메뉴 진입점
- 설정 컴포넌트: `SwitchComponent`, `OptionListComponent`, `SliderComponent`

### 2. Bash (설정 파일 조작)

#### 새 스크립트 작성
```
/home/pangui/scripts/retropangui/scriptmodules/lib/
└── retroarch_config.sh         # 새 파일: RetroArch config 읽기/쓰기 함수
```

#### 주요 함수
```bash
# RetroArch 설정값 읽기
# 사용법: get_retroarch_setting <key> [config_path]
get_retroarch_setting() { ... }

# RetroArch 설정값 쓰기
# 사용법: set_retroarch_setting <key> <value> [config_path]
set_retroarch_setting() { ... }

# 전역 설정 파일 경로 반환
get_global_retroarch_config() { ... }

# 시스템별 설정 파일 경로 반환
get_system_retroarch_config() { ... }

# 게임별 설정 파일 경로 반환
get_game_retroarch_config() { ... }
```

### 3. 연동 방식

```
[ES C++ 코드]
    ↓ (설정 변경 시)
[system() 호출]
    ↓
[bash -c 'source retroarch_config.sh && set_retroarch_setting ...']
    ↓
[retroarch.cfg 파일 업데이트]
```

**참고 예시** (GuiMenu.cpp:815~818):
```cpp
std::string cmd = "bash -c 'source /home/pangui/scripts/retropangui/scriptmodules/lib/retroarch_config.sh && "
    "set_retroarch_setting \"video_vsync\" \"true\"'";
int result = ::system(cmd.c_str());
```

---

## 파일 구조

### 새로 생성할 파일
```
retropangui/
├── docs/
│   └── RETROARCH_MENU_DESIGN.md          # 본 문서
│
├── scriptmodules/lib/
│   └── retroarch_config.sh               # RetroArch 설정 조작 함수
│
└── retropangui-emulationstation/
    └── es-app/src/guis/
        ├── GuiRetroArchSettings.h        # RetroArch 설정 GUI 헤더
        └── GuiRetroArchSettings.cpp      # RetroArch 설정 GUI 구현
```

### 수정할 파일
```
retropangui-emulationstation/
├── es-app/src/guis/
│   ├── GuiMenu.h                         # openRetroArchSettings() 선언 추가
│   └── GuiMenu.cpp                       # 메뉴 항목 및 함수 추가
│
└── es-app/CMakeLists.txt                 # GuiRetroArchSettings.cpp 빌드 추가
```

---

## 개발 단계

### Phase 1: 기획 및 설계 ✅
- [x] ES 메뉴 구조 분석
- [x] RetroArch 설정 계층 구조 정의
- [x] 기획문서 작성

### Phase 2: 백엔드 구현 (Bash)
- [ ] `retroarch_config.sh` 작성
  - [ ] `get_retroarch_setting()` 함수
  - [ ] `set_retroarch_setting()` 함수
  - [ ] 경로 헬퍼 함수들
- [ ] 설정 파일 읽기/쓰기 테스트

### Phase 3: 프론트엔드 구현 (C++)
- [ ] `GuiRetroArchSettings.h/cpp` 작성
  - [ ] 비디오 설정 섹션
  - [ ] 오디오 설정 섹션
  - [ ] 저장 설정 섹션
  - [ ] 기타 설정 섹션
- [ ] `GuiMenu.cpp` 수정
  - [ ] 메뉴 항목 추가
  - [ ] `openRetroArchSettings()` 함수 구현
- [ ] CMakeLists.txt 업데이트

### Phase 4: 빌드 및 테스트
- [ ] ES 빌드
- [ ] 기능 테스트
  - [ ] 설정값 읽기 확인
  - [ ] 설정값 쓰기 확인
  - [ ] 우선순위 적용 확인
- [ ] 버그 수정

### Phase 5: 확장 (향후)
- [ ] 시스템별 설정 오버라이드 UI
- [ ] 게임별 설정 오버라이드 UI (Edit Metadata에 통합)
- [ ] 추가 설정 항목 확대
- [ ] 설정 프리셋 기능

---

## 참고 사항

### 기존 코드 패턴 준수
- **공용 함수 사용 원칙** 준수 (`user.sh`의 권한 관리 함수)
- **로깅**: `LOG(LogInfo/LogDebug/LogError)` 사용
- **설정 저장**: `Settings::getInstance()->set*()` 패턴
- **bash 호출**: `system()` 사용, 스크립트는 `source` 후 함수 호출

### RetroArch 설정 파일 형식
```ini
# 주석
key = "value"
```
- 모든 값은 큰따옴표로 감싸짐
- boolean: `"true"` / `"false"`
- 숫자: `"64"`, `"0.0"`

### 주의사항
- **절대 수정 금지**: `scriptmodules/retropie_setup/` 하위 파일
- **권한 처리**: sudo 환경 고려, `set_dir_ownership_and_permissions()` 사용
- **문서 업데이트**: 주요 변경사항은 HANDOVER.md 및 HISTORY.md에 기록
- **커밋 규칙**: 단계별로 명확한 커밋 메시지 작성

### 참고 링크
- RetroArch 공식 문서: https://docs.libretro.com/
- ES 소스 구조: `/home/pangui/scripts/retropangui-emulationstation/`
- 기존 설정 스크립트: `scriptmodules/lib/retroarch_utils.sh`

---

## 변경 이력

| 날짜 | 작성자 | 내용 |
|------|--------|------|
| 2025-11-09 | LeonardWard | 초안 작성 |

---

**다음 단계**: Phase 2 시작 - `retroarch_config.sh` 백엔드 구현
