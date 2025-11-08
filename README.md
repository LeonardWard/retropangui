# RetroPangui

RetroPangui는 RetroPie EmulationStation 기반의 독자적인 레트로게임 프론트엔드입니다.
복잡한 설정 과정 없이 간편한 메뉴를 통해 레트로 게임 환경을 쉽게 설치하고 관리할 수 있습니다.

## 주요 기능

- **멀티코어 지원**: 시스템별로 여러 개의 에뮬레이터 코어를 선택 가능
- **게임별 코어 선택**: EDIT METADATA 메뉴에서 게임마다 원하는 코어 설정
- **자동화된 설치**: 코어 및 시스템 자동 등록, es_systems.xml 자동 갱신
- **기본 테마 포함**: EmulationStation 설치 시 nostalgia-pure-lite-ko 테마 자동 설치
- **다국어 지원**: 한글/영어 공식 지원 (일본어/중국어 확장 가능)
- **논리 버튼 매핑**: Nintendo/Sony/Xbox 레이아웃 지원
- **RetroPie 호환**: libretro 코어 자동 설치 시스템
- **통합 UI**: Dialog 기반의 직관적인 설정 메뉴

## 요구 사항

- Debian 기반 Linux (Debian, Ubuntu 등)
- sudo 권한
- Git

## 설치

```bash
git clone https://github.com/your-repo/retropangui.git
cd retropangui
sudo ./retropangui_setup.sh
```

## 사용법

### 1. 기본 실행 (UI 메뉴)

```bash
sudo ./retropangui_setup.sh
```

메뉴에서 다음 작업을 수행할 수 있습니다:
- Base System 설치 (RetroArch, EmulationStation, 기초 코어)
- 개별 패키지 설치/제거
- 시스템 업데이트
- 설정 관리

### 2. 패키지 직접 설치 (타입 자동 감지)

```bash
# 단일 패키지 설치
sudo ./retropangui_setup.sh install_module lr-pcsx-rearmed
sudo ./retropangui_setup.sh install_module retroarch
sudo ./retropangui_setup.sh install_module emulationstation

# 여러 패키지 한번에 설치
sudo ./retropangui_setup.sh install_module lr-pcsx-rearmed retroarch emulationstation
```

**자동 타입 감지:**
- `lr-*` 형식 → libretro 코어로 자동 인식
- `retroarch`, `emulationstation` → 특별 케이스 처리
- 파일명 기반 자동 탐색

### 3. UI 없이 환경 설정만

```bash
sudo ./retropangui_setup.sh --no-ui
```

## 프로젝트 구조

```
retropangui/
├── retropangui_setup.sh          # 메인 진입점
├── config.sh                     # 환경변수 설정
├── scriptmodules/                # 핵심 모듈
│   ├── resources/                # 설정 파일 및 리소스
│   │   ├── priorities.conf       # 에뮬레이터 우선순위
│   │   └── themes/               # EmulationStation 테마
│   │       └── nostalgia-pure-lite-ko/  # 기본 테마
│   ├── compat/                   # RetroPie 호환 레이어
│   │   ├── loader.sh             # 호환 레이어 로더
│   │   ├── env.sh                # 환경 설정
│   │   ├── build.sh              # 빌드 함수
│   │   ├── registry.sh           # 에뮬레이터 등록
│   │   └── utils.sh              # 유틸리티
│   ├── lib/                      # 작동 함수들
│   │   ├── log.sh                # 로깅 함수
│   │   ├── user.sh               # 사용자/권한 관리
│   │   ├── version.sh            # 버전 관리
│   │   ├── xml.sh                # XML 조작
│   │   ├── deps.sh               # 의존성 설치
│   │   └── setup.sh              # 환경 설정
│   ├── pkg/                      # 설치할 패키지
│   │   ├── retroarch.sh          # RetroArch
│   │   ├── emulationstation.sh  # EmulationStation (테마 자동 설치)
│   │   └── base_cores.sh         # 기초 코어 묶음
│   └── ui/                       # 사용자 인터페이스
│       └── menu.sh               # Dialog 메뉴
└── docs/                         # 문서
    └── HANDOVER.md               # 핸드오버 문서 (개발 상세 정보)

retropangui-emulationstation/    # EmulationStation 포크 소스
```

## 지원 패키지

### 코어 시스템
- RetroArch
- EmulationStation (커스텀 빌드)

### libretro 코어
- lr-pcsx-rearmed (PlayStation)
- lr-mupen64plus (Nintendo 64)
- lr-np2kai (PC-98)
- lr-scummvm (ScummVM)
- 기타 RetroPie 호환 코어

## 개발 정보

### 리팩토링 현황 (2025-11-08 업데이트)

**Phase 1** ✅ 완료 (2025-11-08):
- ✅ 폴더 구조 재구성 (resources, compat, lib, pkg, ui)
- ✅ 파일 이동 및 경로 수정
- ✅ 타입 자동 감지 시스템
- ✅ config.sh 최상위로 이동

**Phase 2** ✅ 완료 (2025-11-08):
- ✅ func.sh 분할 (493줄 → 5개 모듈 + 19줄 로더)
  - lib/: git, user, config_utils, retroarch_utils, func
  - compat/: packages (RetroPie 호환 함수)
- ✅ packages.sh 분할 (393줄 → 3개 모듈 + 53줄 로더)
  - lib/: install, remove, special
- ✅ 중복 파일 제거 및 통합 (inifuncs.sh + ext_retropie_ini.sh → ini.sh)
- ✅ ES 기본 테마 자동 설치 기능 추가
- ✅ 공용 함수 사용 원칙 확립

**Phase 3** (향후 계획):
- ui/menu.sh 분할 (dialog, config, menu 분리)
- RetroPie 의존성 완전 제거

### 개발 문서

- **핸드오버 문서**: [docs/HANDOVER.md](docs/HANDOVER.md) - 현재 상태 및 개발 가이드
- **개발 이력**: [docs/HANDOVER_ARCHIVE.md](docs/HANDOVER_ARCHIVE.md) - 2025-11-08까지의 전체 개발 이력 (아카이브)

## 라이선스

[라이선스 정보 추가 필요]

## 기여

이슈 및 풀 리퀘스트는 GitHub를 통해 제출해주세요.

## 문의

[문의 정보 추가 필요]
