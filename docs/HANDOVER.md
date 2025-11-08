# RetroPangui 프로젝트 핸드오버 문서

최종 업데이트: 2025-11-08
담당자: LeonardWard
프로젝트 루트: `/home/pangui/scripts/retropangui/`

---

## 📋 목차

1. [프로젝트 개요](#프로젝트-개요)
2. [현재 상태](#현재-상태)
3. [폴더 구조](#폴더-구조)
4. [개발 규칙](#개발-규칙)
5. [빠른 시작](#빠른-시작)
6. [주요 기능](#주요-기능)
7. [참고 문서](#참고-문서)

---

## 프로젝트 개요

**RetroPangui**는 RetroPie EmulationStation 기반의 독자적인 레트로게임 프론트엔드입니다.

- **목표**: RetroPie에서 독립적인 네이티브 시스템으로 전환
- **현재 단계**: Phase 2 완료 (리팩토링 완료, 구조 안정화)
- **다음 단계**: Phase 3 (RetroPie 의존성 완전 제거)

---

## 현재 상태

### 리팩토링 현황

**✅ Phase 1 완료 (2025-11-08)**
- 폴더 구조 재구성 (resources, compat, lib, pkg, ui)
- config.sh 최상위로 이동
- 타입 자동 감지 시스템

**✅ Phase 2 완료 (2025-11-08)**
- `func.sh` 분할 (493줄 → 5개 모듈)
- `packages.sh` 분할 (393줄 → 3개 모듈)
- 중복 함수 제거 및 통합
- ES 기본 테마 자동 설치 기능 추가
- 공용 함수 사용 원칙 확립

**⏳ Phase 3 (향후 계획)**
- `ui/menu.sh` 분할
- RetroPie 의존성 완전 제거

---

## 폴더 구조

```
/home/pangui/scripts/retropangui/
├── retropangui_setup.sh           # 메인 진입점
├── config.sh                      # 전역 환경 변수
│
├── scriptmodules/
│   ├── resources/                 # 리소스 파일
│   │   ├── priorities.conf        # 에뮬레이터 우선순위
│   │   └── themes/                # ES 테마
│   │       └── nostalgia-pure-lite-ko/  # 기본 테마
│   │
│   ├── compat/                    # RetroPie 호환 레이어 (미래 제거 예정)
│   │   ├── loader.sh              # 호환 레이어 통합 로더
│   │   ├── env.sh                 # 환경 설정
│   │   ├── build.sh               # 빌드 함수
│   │   ├── registry.sh            # 에뮬레이터 등록
│   │   └── utils.sh               # 유틸리티
│   │
│   ├── lib/                       # 네이티브 작동 함수들
│   │   ├── log.sh                 # 로깅
│   │   ├── git.sh                 # Git 작업
│   │   ├── user.sh                # 사용자/권한 (공용 함수)
│   │   ├── config_utils.sh        # 설정 파일 유틸리티
│   │   ├── retroarch_utils.sh     # RetroArch 유틸리티
│   │   ├── xml.sh                 # XML 조작
│   │   ├── ini.sh                 # INI 파싱
│   │   ├── version.sh             # 버전 관리
│   │   ├── packages.sh            # 패키지 관리 통합 로더
│   │   ├── install.sh             # 설치 로직
│   │   ├── remove.sh              # 제거 로직
│   │   ├── special.sh             # 특수 케이스
│   │   ├── deps.sh                # 의존성 설치
│   │   └── setup.sh               # 환경 설정
│   │
│   ├── pkg/                       # 설치 패키지들
│   │   ├── system_install.sh      # Base System 통합 설치
│   │   ├── retroarch.sh           # RetroArch 패키지
│   │   ├── emulationstation.sh    # EmulationStation 패키지
│   │   └── base_cores.sh          # 기초 코어 묶음
│   │
│   └── ui/                        # 사용자 인터페이스
│       └── menu.sh                # Dialog 메뉴
│
└── docs/
    ├── HANDOVER.md                # 핸드오버 문서 (본 문서)
    └── HANDOVER_ARCHIVE.md        # 개발 이력 아카이브 (2025-11-08까지)
```

---

## 개발 규칙

### 1. 공용 함수 사용 원칙 ⭐

**필수 규칙**: 디렉토리 생성 및 권한 설정 시 반드시 공용 함수 사용

```bash
# ❌ 잘못된 방식 (금지)
mkdir -p /some/path
chown user:user /some/path

# ✅ 올바른 방식
local target_user
target_user="$(set_dir_ownership_and_permissions "/some/path")" || return 1
# target_user 변수로 이후 파일 소유권 설정
sudo chown "$target_user":"$target_user" /some/file
```

**이유**: 사용자 권한 처리의 일관성 유지, sudo 환경에서의 안전성 확보

**적용 범위**: 모든 설치 스크립트, 설정 스크립트, 자동화 스크립트

### 2. RetroPie 호환 레이어 분리

- `compat/` 폴더의 파일은 RetroPie 호환용
- `lib/` 폴더의 파일은 RetroPangui 네이티브 함수
- **절대 수정 금지**: `scriptmodules/retropie_setup/` 하위 모든 파일

### 3. 코드 변경 절차

1. **변경 이전**: 관련 모듈, 함수, config 파일 숙지
2. **설계 방안 검토**: 기존 방식에 부합하는 형태로 설계
3. **수정 및 적용**: 공용 함수 사용 원칙 준수
4. **커밋 및 기록**: 커밋 메시지와 함께 본 문서에 기록
5. **테스트 및 검증**: 전체 기능 테스트

### 4. 문서 관리

- **HANDOVER.md**: 현재 상태 및 핵심 정보 (계속 업데이트)
- **HANDOVER_ARCHIVE.md**: 2025-11-08까지의 전체 개발 이력 (업데이트 안 함)
- **README.md**: 사용자 대상 문서 (원격지 푸시)

---

## 빠른 시작

### 설치

```bash
# 1. 프로젝트 클론
git clone https://github.com/LeonardWard/retropangui.git
cd retropangui

# 2. 기본 시스템 설치 (UI 메뉴)
sudo ./retropangui_setup.sh

# 3. 또는 직접 설치 (타입 자동 감지)
sudo ./retropangui_setup.sh install_module lr-pcsx-rearmed
```

### 개발 시작

```bash
# 1. 최신 커밋 확인
git log --oneline -10

# 2. 환경 변수 확인
cat config.sh

# 3. 공용 함수 확인
cat scriptmodules/lib/user.sh
```

---

## 주요 기능

- **멀티코어 지원**: 시스템별로 여러 개의 에뮬레이터 코어 선택 가능
- **게임별 코어 선택**: EDIT METADATA 메뉴에서 게임마다 원하는 코어 설정
- **자동화된 설치**: 코어 및 시스템 자동 등록, es_systems.xml 자동 갱신
- **기본 테마 포함**: EmulationStation 설치 시 nostalgia-pure-lite-ko 테마 자동 설치
- **다국어 지원**: 한글/영어 공식 지원
- **논리 버튼 매핑**: Nintendo/Sony/Xbox 레이아웃 지원
- **RetroPie 호환**: libretro 코어 자동 설치 시스템

---

## 최근 주요 변경사항

### 2025-11-08
- ES 설치 시 기본 테마(nostalgia-pure-lite-ko) 자동 설치 기능 추가
- 공용 함수 사용 원칙 확립 (`set_dir_ownership_and_permissions`)
- Phase 2 리팩토링 완료 (func.sh, packages.sh 분할)
- 문서 구조 개선 (HANDOVER_ARCHIVE.md 분리)

### 2025-11-02
- RetroPie 호환 패키지 설치 시스템 구축
- libretro 코어 자동 설치 지원

### 2025-11-01
- EDIT METADATA 코어 선택 기능 완전 구현

---

## 참고 문서

- **전체 개발 이력**: [HANDOVER_ARCHIVE.md](HANDOVER_ARCHIVE.md)
- **사용자 가이드**: [../README.md](../README.md)
- **GitHub**: https://github.com/LeonardWard/retropangui
- **EmulationStation 포크**: `/home/pangui/scripts/retropangui-emulationstation/`

---

## 문의 및 기여

주요 변경사항은 반드시 본 문서에 기록하고, 커밋 메시지에 명확히 작성해주세요.

**공지**: 문의 및 주요 변경 시에는 반드시 본 문서에 주석 추가 후, 담당자 또는 GitHub Issue로 기록/공유 바랍니다.
