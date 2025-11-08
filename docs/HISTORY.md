# RetroPangui 프로젝트 변경 이력

> **📝 변경 이력 문서**
> 이 문서는 프로젝트의 주요 변경사항을 시간순으로 기록합니다.
> 새로운 변경사항은 최상단에 추가합니다.

---

## 2025-11-09

### 문서 통합 및 구조 최종 정리
- HANDOVER_ARCHIVE.md 통합 (4100줄)
  - Part 1 (2025-08~10-25): 초기 개발 및 아키텍처 결정
  - Part 2 (2025-10-26): 프로젝트 안정화 및 문서화
  - Part 3 (2025-10-26~11-08): 최신 개발 이력
- HANDOVER.md를 원격지 푸시 가능하도록 변경
- 통합된 원본 파일 삭제 (handover_retropangui.md, README.md.bak)
- HISTORY.md 생성 (변경 이력 분리)

---

## 2025-11-08

### ES 기본 테마 자동 설치 및 공용 함수 사용 원칙 확립
- **ES 기본 테마 자동 설치**
  - nostalgia-pure-lite-ko 테마를 ES 설치 시 자동으로 설치
  - 위치: `resources/themes/nostalgia-pure-lite-ko/`
  - 설치 경로: `~/.emulationstation/themes/`

- **공용 함수 사용 원칙 확립**
  - `set_dir_ownership_and_permissions()` 공용 함수 사용 의무화
  - 직접 `chown`, `mkdir` 호출 금지
  - 모든 설치 스크립트에서 일관성 확보

### Phase 2 리팩토링 완료
- **func.sh 분할** (493줄 → 5개 모듈 + 19줄 로더)
  - `lib/git.sh`: Git 작업
  - `lib/user.sh`: 사용자/권한
  - `lib/config_utils.sh`: 설정 파일 유틸리티
  - `lib/retroarch_utils.sh`: RetroArch 유틸리티
  - `compat/packages.sh`: RetroPie 호환 함수

- **packages.sh 분할** (393줄 → 3개 모듈 + 53줄 로더)
  - `lib/install.sh`: 설치 로직
  - `lib/remove.sh`: 제거 로직
  - `lib/special.sh`: 특수 케이스

- **중복 함수 제거 및 통합**
  - `inifuncs.sh` + `ext_retropie_ini.sh` → `lib/ini.sh`

### 문서 구조 개선
- HANDOVER_ARCHIVE.md 분리 (2025-11-08까지 이력 보관)
- 새로운 간결한 HANDOVER.md 작성 (223줄)

---

## 2025-11-02

### RetroPie 호환 패키지 설치 시스템 구축
- libretro 코어 자동 설치 지원
- RetroPie-Setup 스크립트 호환 레이어 구축
- `compat/` 폴더에 호환 함수 분리

### 성공적으로 테스트된 코어
- lr-pcsx-rearmed (PlayStation)
- lr-mupen64plus (Nintendo 64)
- lr-np2kai (PC-98)
- lr-scummvm (ScummVM)

---

## 2025-11-01

### EDIT METADATA 코어 선택 기능 완전 구현
- EDIT THIS GAME'S METADATA 메뉴에서 EMULATOR 필드를 통해 게임별로 특정 코어 선택 가능
- OptionListComponent를 사용한 드롭다운 UI 구현
- Auto (Default) + 시스템의 모든 사용 가능한 코어 목록 표시
- 선택한 코어가 gamelist.xml에 `<core>` 태그로 저장됨
- 게임 실행 시 gamelist.xml의 코어 정보를 우선 사용

---

## 2025-10-31

### 다국어 지원 최종 적용
- 한글, 영어, 일본어, 중국어 지원
- UI 전체 번역 적용 (_() 매크로)
- Settings UI에서 실시간 언어 변경 가능
- 모든 번역/폰트 fallback 검증 완료
- CMake 빌드·locale 파일 자동 배포

---

## 2025-10-30

### systemlist.csv 구조 완전 자동화
- 시스템 정의 자동화
- 권한 복구 시스템 추가

---

## 2025-10-28

### 코어 자동등록/설정 자동화
- 패치 방식 완전 폐기
- 자동화 스크립트 기반으로 전환

---

## 2025-10-25

### 커밋/테스트 검증 및 다국어 시스템 초안 적용
- 다국어 시스템 기초 구축
- 테스트 체계 수립

---

## 2025-10-24

### 멀티코어/ShowFolders 지원, 자동화 구조 기초 구현
- 멀티코어 지원 시스템 구축
- ShowFolders 3옵션 추가
- 자동화 구조 설계

---

## 2025-10-23

### ES 논리 버튼 매핑 및 UI 옵션 구조 완성
- Nintendo/Sony/Xbox 레이아웃 지원
- 논리 버튼 매핑 시스템 구현
- UI 옵션 구조 완성

---

## 이전 개발 이력

2025-08 ~ 2025-10-23 이전의 상세한 개발 이력은 [HANDOVER_ARCHIVE.md](HANDOVER_ARCHIVE.md)를 참조하세요.
