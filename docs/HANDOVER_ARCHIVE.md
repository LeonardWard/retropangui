# RetroPangui 프로젝트 개발 이력 아카이브

> **⚠️ 아카이브 문서**
> 이 문서는 2025-11-08까지의 전체 개발 이력을 보관한 아카이브입니다.
> **더 이상 업데이트되지 않습니다.**
> 최신 핸드오버 정보는 [HANDOVER.md](HANDOVER.md)를 참조하세요.

---

# RetroPangui 프로젝트 핸드오버 문서 (보존본)

작성일자: 2025-10-31
담당자: LeonardWard
프로젝트 루트: `/home/pangui/scripts/retropangui/`
핸드오버 세션: ES 멀티코어 지원, 자동화, 다국어 추가 완료 기준
아카이브 날짜: 2025-11-08

---

## 수정 이력

| 날짜        | 주요 변경 내용                                | 담당자         |
|-------------|-----------------------------------------------|----------------|
| 2025-10-23  | ES 논리 버튼 매핑 및 UI 옵션 구조 완성         | LeonardWard    |
| 2025-10-24  | 멀티코어/ShowFolders 지원, 자동화 구조 기초 구현| LeonardWard    |
| 2025-10-25  | 커밋/테스트 검증 및 다국어 시스템 초안 적용    | LeonardWard    |
| 2025-10-28  | 코어 자동등록/설정 자동화, 패치방식 완전 폐기  | LeonardWard    |
| 2025-10-30  | systemlist.csv/구조 완전 자동화, 권한복구 추가 | LeonardWard    |
| 2025-10-31  | 다국어 지원 최종 적용, 인수인계 커밋/배포 가이드 추가 | LeonardWard    |
| 2025-11-01  | EDIT METADATA 코어 선택 기능 완전 구현 및 수정 | LeonardWard    |
| 2025-11-02  | RetroPie 호환 패키지 설치 시스템 구축 (libretrocores) | LeonardWard    |
| 2025-11-04  | 스크립트 리팩토링 계획 수립 (중복 제거, 복잡도 관리, 독립화) | Claude (AI)    |
| 2025-11-08  | 리팩토링 구조 확정 (resources, compat, lib, pkg, ui) | Claude (AI)    |
| 2025-11-08  | Phase 1 완료: 폴더 구조 생성 및 파일 이동 | Claude (AI)    |
| 2025-11-08  | Phase 2 완료: func.sh, packages.sh 완전 분할 | Claude (AI)    |
| 2025-11-08  | ES 설치 시 기본 테마(nostalgia-pure-lite-ko) 자동 설치 기능 추가 | Claude (AI)    |
| 2025-11-08  | 공용 함수 사용 원칙 확립 및 문서화 | Claude (AI)    |

---

## 1. 프로젝트 개요

- 프로젝트명: **RetroPangui**
- 개발 목표: RetroPie EmulationStation 기반의 독자적 레트로게임 프론트엔드 구축
- 참고 아키텍처: RetroArch, Emulationstation, Recalbox, Batocera, ES-DE, Retropie 등

---

## 2. 인수인계 체크리스트

```
- [x] 전체 아키텍처와 폴더/파일 구조 이해
- [x] 최신 커밋 로그 및 핵심 변경사항 확인
- [x] 멀티코어/논리버튼 등 핵심 구현부 소스 리뷰
- [x] 자동화 스크립트 동작 및 설정파일 생성 로직 점검
- [x] 다국어(locale) 번역 및 폰트 fallback 정상 동작 검증
- [x] 신규 locale 추가 및 빌드/테스트 확인
- [x] 기능(게임 실행, 설정, 폴더 표시 등) 테스트 수행
- [x] 환경변수 및 자동화 경로 구조 적용 확인
- [x] 문서 및 개발자 가이드 참고
```

---


## 3. 폴더 및 파일 구조

### 3.1 메인 프로젝트 경로 상세 설명

`/home/pangui/scripts/retropangui/`  
RetroPangui 프로젝트의 전체 관리, 자동화 및 배포 스크립트가 위치합니다.

```
/home/pangui/scripts/retropangui/
├── .git/                              # 전체 프로젝트의 버전 관리(로컬 커밋, 푸시)
├── .gitignore                         # 빌드 산출물/임시파일 등 무시 설정
├── deburg_init_script.sh               # 디버깅 초기화 전용 스크립트(실행환경 점검)
├── handover_retropangui.md             # 프로젝트 핸드오버 및 인수인계 문서(본 문서)
├── log/                               # 실행 및 설치 중 로그 기록 디렉토리
├── resources/                         # 에뮬레이션, UI, 설정에 필요한 이미지/아이콘/패치/폰트/locale 등 리소스 관리
│   ├── patches/                       # ES 및 관련 플젝을 위한 레거시 패치파일(legacy)
│   ├── locale/                        # 다국어 번역, 폰트 관리
│   └── fonts/                         # 한글 등 폰트 fallback 파일
├── retropangui_setup.sh                # 메인 진입/설치/런처 스크립트
└── scriptmodules/                     # 핵심 기능별 bash/shell 자동화 모듈 디렉토리
    ├── config.sh                      # 전역 환경 변수 설정, 경로 정의
    ├── resources/                     # 리소스 파일
    │   ├── priorities.conf            # 에뮬레이터 우선순위 설정
    │   └── themes/                    # ES 테마
    │       └── nostalgia-pure-lite-ko/ # 기본 테마
    ├── compat/                        # RetroPie 호환 레이어 (미래 제거 예정)
    │   ├── loader.sh                  # 호환 레이어 통합 로더
    │   ├── env.sh                     # 환경 설정
    │   ├── build.sh                   # 빌드 함수
    │   ├── registry.sh                # 에뮬레이터 등록
    │   └── utils.sh                   # 유틸리티
    ├── lib/                           # 작동 함수들 (RetroPangui 네이티브)
    │   ├── log.sh                     # 로깅
    │   ├── git.sh                     # Git 작업
    │   ├── user.sh                    # 사용자/권한 (set_dir_ownership_and_permissions)
    │   ├── config_utils.sh            # 설정 파일 유틸리티
    │   ├── retroarch_utils.sh         # RetroArch 유틸리티
    │   ├── func.sh                    # 통합 로더
    │   ├── ini.sh                     # INI 파싱
    │   ├── xml.sh                     # XML 조작
    │   ├── version.sh                 # 버전 관리
    │   ├── packages.sh                # 패키지 관리 통합 로더
    │   ├── install.sh                 # 설치 로직
    │   ├── remove.sh                  # 제거 로직
    │   ├── special.sh                 # 특수 케이스
    │   ├── deps.sh                    # 의존성 설치
    │   └── setup.sh                   # 환경 설정
    ├── pkg/                           # 설치할 패키지들
    │   ├── system_install.sh          # Base System 통합 설치
    │   ├── retroarch.sh               # RetroArch 패키지
    │   ├── emulationstation.sh        # EmulationStation 패키지 (테마 자동 설치 포함)
    │   └── base_cores.sh              # 기초 코어 묶음
    └── ui/                            # 사용자 인터페이스
        └── menu.sh                    # 메뉴 로직
```

#### 주요 목적·관리 포인트

- **핵심 진입/설치자동화:** `retropangui_setup.sh` 단일 스크립트로 전체 환경 구축 및 배포 관리  
- **모듈별 자동화 설계:** 모든 install_base_*.sh, packages.sh가 단계별로 작업을 독립, 연동하는 모듈 구조  
- **코어 업데이트 및 시스템 등록:** install_base_4_in_5_cores.sh, es_systems_updater.sh가 코어 및 시스템 자동 추가 갱신  
- **리소스/설정 통합관리:** resources/ 폴더(이미지, locale, 폰트, 패치)에서 모든 UI/다국어/빌드 옵션을 통합 관리  
- **환경변수/경로 일원관리:** config.sh와 각 install_base_*.sh에서 모든 경로/변수 관리 및 에러 방지
- **공식 인수인계 문서:** handover_retropangui.md에 모든 작업, 변경, 커밋 기록과 함께 최신 가이드·체크리스트 명시  

#### 신규 관리자가 반드시 수행해야 할 것

- 모든 주요 스크립트/모듈의 주석 및 사용법 파악  
- `config.sh` 환경 매개변수 및 중요 경로 재확인 후 본인의 시스템에 적용  
- 변경/수정 작업 발생 시 반드시 커밋·추가 반영 및 핸드오버 문서에 기록  
- 리소스(`resources/`), 시스템(코어, XML 등), 설정파일 관련 경로/적용여부 점검 필수

---

### 3.2 ES(EmulationStation) 포크 소스 경로

```
/home/pangui/scripts/retropangui-emulationstation/
├── .git/
├── .gitignore
├── CMakeLists.txt
├── es-app/
├── es-core/
├── resources/
│   └── locale/    # 다국어 번역 파일(.po, .mo)
│   └── fonts/     # 각국어 폰트/폴백
├── tools/
└── 기타 소스 폴더
```

---

## 4. 빌드 및 설정파일 자동화 구조

- 코어 및 시스템 자동등록: es_systems.xml, es_settings.cfg  
- 자동화 예시
  ```
  cat > ~/.emulationstation/es_settings.cfg <<'EOF'
  <?xml version="1.0"?>
  <string name="RetroArchPath" value="/opt/retropangui/bin/retroarch" />
  <string name="LibretroCoresPath" value="/opt/retropangui/libretrocores" />
  <string name="CoreConfigPath" value="/home/pangui/share/system/configs/cores" />
  EOF
  ```

  ```
  <systemList>
    <system>
      <name>psx</name>
      ommandnd>/opt/retropangui/bin/retroarch -L %CORE% --config %CONFIG% %ROM%</command>
      oreses>
        ore name="pcsx_rearmed" module_id="lr-pcsx-rearmed" priority="2" extensions=".bin .cue .imgmg"/>
        <re name="beetle_psx" module_id="lr-beetle-psx" priority="3" extensionsns=".chd"/>
      </cores>
      <platform>psx</platform>
      <theme>psx</theme>
    </system>
    ...
  </systemList>
  ```

---

## 5. 다국어(locale) 지원 현황

- **지원 언어**: 한글, 영어, 일본어, 중국어 등 4개 언어
- **구현 방식**:
  - `resources/locale` 내 .po/.mo 번역 파일 관리
  - UI 전체 번역(_() 매크로 적용)
  - Settings UI에서 실시간 언어 변경 가능
  - 모든 번역/폰트 fallback 검증 완료
  - CMake 빌드·locale 파일 자동 배포(2025-10-31 최종반영)

---

## 6. 핵심 구현 및 개선 내역

- ES 멀티코어 지원: command 템플릿 변수 치환, module_id 기반 동적 코어 처리
- 논리 버튼 매핑 및 UI 레이아웃 옵션 추가: (Nintendo/Sony/Xbox)
- ShowFolders 3옵션, UI-설정 즉시 반영
- 자동화 스크립트(코어, 시스템 동적등록) 및 권한복구
- 다국어 번역 및 폰트 fallback
- **ES 기본 테마 자동 설치** (2025-11-08): EmulationStation 설치 시 nostalgia-pure-lite-ko 테마 자동 설치
  - 위치: `scriptmodules/pkg/emulationstation.sh`
  - 테마 소스: `resources/themes/nostalgia-pure-lite-ko`
  - 설치 경로: `~/.emulationstation/themes/nostalgia-pure-lite-ko`

---

## 7. 테스트 체크리스트

```
- [x] ES 전체 빌드 성공 및 실행 확인
- [x] 다국어 번역, 폰트 fallback, 신규 locale 파일 동작 테스트
- [x] 코어 설치시 es_systems.xml 자동 갱신 확인
- [x] es_settings.cfg 값 적용(경로, 환경변수) 정상 확인
- [x] UI/폴더/논리버튼/다국어 등 모든 기능 정상 동작
- [x] 패치 폐기 및 Git/Upstream 동기화 가능 확인
- [x] 파일 권한 자동복구 로직 정상 확인
```

---

## 8. 커밋 및 변경 이력 (주요 커밋만 발췌)

```
retropangui-emulationstation:
- fdab176  ES 멀티코어 module_id 도입
- 910b89d  코어 경로 동적 탐색
- d1d68d9  command 템플릿-변수 치환
- [다국어 추가] localeES, 신규 폰트/번역 적용

retropangui:
- 75b6a8d  코어설치시 es_systems.xml 자동갱신
- 514ac19  XML 파일 권한자동복구
- [다국어] locale 파일, 빌드 스크립트 개선
```

---

## 9. 개발 및 핸드오버 커밋/배포 가이드

> **❗️ 커밋/빌드/배포 실무 절차**

1. **모든 코드/설정/스크립트 수정 내역은 각 커밋 메시지에 변경사항 요약을 필수로 남깁니다.**
2. **로컬 브랜치 빌드 및 테스트로 정상 동작 확인**
3. **모든 변경을 원격(GitHub origin)에 직접 push하여 커밋/배포를 완료합니다.(HANDOVER.md는 제외)**
   ```
   git add <수정_파일>
   git commit -m "변경 내역 요약"
   git push origin main
   ```
4. **최종 빌드는 사용자 책임(관리자)입니다. 개발자는 커밋과 원격 반영까지 진행합니다.**
5. **인수인계 후 최신 커밋 로그와 변경사항은 본 문서에 기록하세요.**
6. ****

---

## 10. 다음 세션 시작 가이드

```
cd /home/pangui/scripts/retropangui
git log --oneline -10
cd /home/pangui/scripts/retropangui-emulationstation
git log --oneline -5
# 게임 실행, 다국어(locale) 설정/테스트
# 향후 개선 과제(코어선택UI 등) 참조
```

---

## 11. 향후 개선 및 추가 문서화

- **게임별 코어 선택 기능 (EDIT METADATA)**
  **✅ 구현 완료 (2025-11-01)**

  **구현 내용:**
  - EDIT THIS GAME'S METADATA 메뉴에서 EMULATOR 필드를 통해 게임별로 특정 코어 선택 가능
  - OptionListComponent를 사용한 드롭다운 UI 구현
  - Auto (Default) + 시스템의 모든 사용 가능한 코어 목록 표시
  - 좌우 방향키 또는 Accept 버튼으로 코어 선택
  - 선택한 코어가 gamelist.xml에 `<core>` 태그로 저장됨
  - 게임 실행 시 gamelist.xml의 코어 정보를 우선 사용

  **주요 수정 파일:**
  - `es-app/src/guis/GuiMetaDataEd.cpp`: core 필드 OptionListComponent 처리 및 save/hasChanges 로직
  - `es-core/src/components/OptionListComponent.h`: getValue()/setValue() 템플릿 메서드 추가
  - `es-app/src/guis/GuiGamelistOptions.cpp`: 불필요한 SELECT EMULATOR 메뉴 제거

  **기술적 세부사항:**
  - OptionListComponent<std::string> 사용
  - dynamic_cast를 통한 타입 안전성 확보 (save 및 hasChanges 함수)
  - input_handler를 통한 입력 전달 (좌우 방향키, Accept 버튼)
  - metadata 변경 감지 및 저장 확인 프롬프트 정상 작동

  **커밋 이력:**
  ```
  retropangui-emulationstation:
  - f71ed65  Fix: hasChanges() now properly detects core field changes
  - cc2c809  Clean up: Remove debug logging
  - 76dd78f  Fix: Use dynamic_cast to get OptionListComponent value for core field
  - 3daa5be  Debug: Add logging and restore third parameter for row.addElement
  - 777b2f4  Fix: Change row.addElement to use 2 params for core field
  - ef23071  Fix EMULATOR field in EDIT METADATA: Add OptionListComponent support
  ```

- **HelpPrompt 동적 버튼 표기**  
  현재 미구현(물리 버튼 표기 유지), 향후 ButtonLayout(논리 배치) 변경에 따라 하단 도움말도 논리/레이아웃별 동적으로 표기될 수 있도록 구조 개선 필요.
  - 사용자 입장에서 혼동을 없애기 위해, HelpPrompt가 실제 ButtonLayout에 따라 B=확인, A=취소 등으로 정확히 안내되도록 변경 예정.
  - 소스 수정 위치 및 개선 방안은 인수인계 문서에 제안으로 기록.

- **다국어 정책**  
  - 현재 프로젝트는 한글과 영문만 공식적으로 지원합니다.
  - 일본어/중국어 등 추가 언어 지원 및 번역/배포 정책은 별도 관리자 또는 팀 전환 시 논의하여 확장 가능.
  - 리소스 및 locale 구조는 확장성 있게 설계되어 있으나, 번역/해당 문서 작성은 한글 및 영문에 한함.

- **README/설치/개발자 가이드**  
  - 공식 문서(README.md, 설치 가이드, 개발자 가이드 등)는 한글·영문 버전만 관리 및 배포합니다.
  - 기존 문서는 handover_retropangui.md에 통합 안내하며, 신규 문서 추가 시에도 반드시 한글·영문 양식으로 작성/관리합니다.

---

## 12. 코드/설정 변경 및 인수인계 시 유의사항

- **기존 로직 전수 파악(필수)**
  - 모든 코드, 스크립트, 설정 변경 또는 신규 기능 추가 전에는 반드시 기존 로직 전체 구조와 흐름을 꼼꼼히 점검해야 합니다.
  - 기존 함수/모듈의 설계, 사용 방식, 의존성, 동작 타이밍, 예외처리 방식 등을 충분히 이해하고 문서/주석을 확인합니다.
  - 불필요하게 새로운 구조나 패턴을 새로 도입하기보다, 프로젝트 전체의 일관성 및 유지보수성, 기존 정책에 맞는 방식으로 작업을 처리해야 합니다.

- **공용 함수 사용 원칙 (2025-11-08 확립)**
  - **필수**: 디렉토리 생성 및 권한 설정 시 반드시 `set_dir_ownership_and_permissions()` 공용 함수 사용
  - **금지**: `mkdir`, `chown`, `chmod` 등을 직접 호출하지 않고 공용 함수 사용
  - **위치**: `scriptmodules/lib/user.sh`에 정의된 함수들 활용
  - **이유**: 사용자 권한 처리의 일관성 유지, sudo 환경에서의 안전성 확보
  - **예시**:
    ```bash
    # 잘못된 방식 (사용 금지)
    mkdir -p /some/path
    chown user:user /some/path

    # 올바른 방식
    local target_user
    target_user="$(set_dir_ownership_and_permissions "/some/path")" || return 1
    # target_user 변수로 이후 파일 소유권 설정 시 사용
    ```
  - **적용 범위**: 모든 설치 스크립트, 설정 스크립트, 자동화 스크립트

- **변경·수정 절차**
  1. **변경 이전**: 관련 모듈, 함수, config 파일, 자동화 로직을 모두 정독 및 이해.
  2. **설계 방안 검토**: 본래 방식·로직에 최대한 부합하는 형태로 개선/확장 방법 설계.
  3. **수정 및 적용**: 일관성을 유지하며, 기존 흐름에 맞게 신규 코드를 추가하거나 변경. **공용 함수 사용 원칙 준수**.
  4. **커밋 및 기록**: 모든 변경 내용은 커밋 메시지와 함께 인수인계 문서에 명확히 기록.
  5. **테스트 및 검증**: 수정 후 전체 기능 테스트로 기존 기능, 연동 모듈, 로그, 자동화 스크립트가 정상 작동하는지 확인.

- **핸드오버 문서 반영**
  - 모든 주요 변경사항(함수, 모듈, 프로세스, 설정파일 등)은 본 핸드오버 문서에 반드시 기록/주석 추가 또는 변경 이력에 반영
  - 신규 관리자는 추후 인수인계 시 위 절차와 정책을 지켜야 함

---

---

## 13. RetroPie 호환 패키지 설치 시스템 (2025-11-02 추가)

### 13.1 개요

RetroPie-Setup 스크립트와 호환되는 libretro 코어 자동 설치 시스템을 구축했습니다.
`scriptmodules/retropie_setup/` 하위의 원본 RetroPie 스크립트를 **수정 없이** 사용하며,
호환 레이어(`ext_retropie_*.sh`)를 통해 동작합니다.

### 13.2 핵심 설계 원칙

**⚠️ 중요: RetroPie 원본 파일 수정 금지**

```
/home/pangui/scripts/retropangui/scriptmodules/retropie_setup/
```

이 디렉토리 하위의 모든 파일은 **절대 수정하지 않습니다**.
대신 `scriptmodules/` 루트의 확장 스크립트를 통해 호환성을 제공합니다.

### 13.3 파일 구조 및 역할

#### 핵심 파일들

```
scriptmodules/
├── config.sh                    # 전역 환경변수 (경로, 플랫폼 설정)
├── packages.sh                  # 모듈 설치 메인 로직
├── ext_retropie_core.sh         # RetroPie 호환 레이어 통합
├── ext_retropie_env.sh          # RetroPie 호환 환경 설정 (플랫폼, GCC, CFLAGS)
├── ext_retropie_func.sh         # RetroPie 호환 플랫폼/버전 감지
├── ext_retropie_util.sh         # RetroPie 호환유틸리티 함수
├── ext_retropie_op.sh           # RetroPie 호환 동작 함수 (addEmulator 등)
├── ext_retropie_inst.sh         # RetroPie 호환 설치 관련 함수 (getDepends, gitPullOrClone 등)
├── ext_retropie_ini.sh          # RetroPie 호환 INI 파일 처리
└── retropie_setup/              # RetroPie 원본 (수정 금지!)
    └── scriptmodules/
        └── libretrocores/
            ├── lr-*.sh          # 각 코어별 설치 스크립트
            └── lr-*/            # 코어별 패치 파일
```

#### 각 파일의 역할

**config.sh**
- 전역 경로 및 환경변수 정의
- 플랫폼 감지 (`__platform`, `__platform_flags`)
- CPU 플래그 설정 (`__default_cpu_flags`, `__default_opt_flags`)
- RetroPie 호환 변수 (`emudir`, `biosdir`)

**packages.sh**
- `install_module()`: 모듈 설치 메인 함수
- `remove_module()`: 모듈 제거 함수
- 단계별 실행: depends → sources → build → install → configure
- es_systems.xml 자동 업데이트
- 특수 케이스 처리 (`get_special_core_info()`)

**ext_retropie_inst.sh**
- `gitPullOrClone()`: git 저장소 클론 (커밋 해시 지원)
- `getDepends()`: 의존성 패키지 자동 설치
- `installLibretroCore()`: 빌드 산출물 복사 및 설치
- `hasPackage()`: dpkg 패키지 설치 확인 (개선됨)

**ext_retropie_env.sh**
- `setup_env()`: 환경 초기화
- GCC 14+ 호환성: `-Wno-error=incompatible-pointer-types`, `-Wno-error=int-conversion`
- CFLAGS/CXXFLAGS 설정

**ext_retropie_op.sh**
- `applyPatch()`: 패치 파일 적용 (빌드 디렉토리에서)
- `addEmulator()`: 에뮬레이터 등록
- `defaultRAConfig()`: RetroArch 설정 생성

**ext_retropie_util.sh**
- `mkRomDir()`: ROM 디렉토리 생성
- `isPlatform()`: 플랫폼 플래그 확인
- `runCmd()`: 명령 실행 및 오류 로깅

### 13.4 설치 프로세스

#### 단계별 실행 흐름

1. **depends**: 의존성 패키지 설치
   - `getDepends`로 apt 패키지 자동 설치
   - 실패 시 전체 설치 중단

2. **sources**: 소스 코드 다운로드
   - `gitPullOrClone`으로 git 저장소 클론
   - 특정 커밋/브랜치 체크아웃 지원
   - 빌드 디렉토리: `/tmp/retropangui/<module_id>`

3. **build**: 빌드 실행
   - 빌드 디렉토리로 이동 후 `build_<module_id>` 함수 실행
   - 플랫폼별 파라미터 자동 적용
   - `md_ret_require` 검증

4. **install**: 파일 복사 준비
   - `install_<module_id>` 함수로 `md_ret_files` 설정
   - **즉시** `installLibretroCore` 호출하여 파일 복사
   - 설치 경로: `/opt/retropangui/libretrocores/<module_id>`

5. **configure**: 설정 및 등록
   - `configure_<module_id>` 함수 실행
   - RetroArch 설정 생성
   - 에뮬레이터 등록

6. **es_systems.xml 업데이트**
   - 코어 정보 추출 (system, extensions)
   - 우선순위 설정
   - XML 자동 갱신

### 13.5 주요 개선 사항 및 버그 수정

#### 2025-11-02 세션에서 해결한 문제들

1. **패치 파일 경로 문제**
   - 문제: `md_data` 변수 미설정으로 패치 파일을 찾지 못함
   - 해결: `packages.sh`에 `md_data` export 추가
   - 해결: `applyPatch()` 함수에 자동 경로 보정 로직 추가

2. **플랫폼 설정 누락**
   - 문제: x86_64에 RetroPie 방식의 플랫폼 플래그 없음
   - 해결: `config.sh`에 `__default_cpu_flags="-march=native"` 추가
   - 해결: `__platform_flags`에 `gl`, `vulkan`, `x11` 추가

3. **GCC 14 호환성**
   - 문제: `-Wincompatible-pointer-types`, `-Wint-conversion` 오류
   - 해결: `ext_retropie_env.sh`에 GCC 14+ 감지 및 플래그 추가

4. **커밋 해시 지원**
   - 문제: `gitPullOrClone`이 커밋 해시를 처리하지 못함
   - 해결: 4번째 파라미터로 커밋 해시 읽고 체크아웃

5. **hasPackage 버그**
   - 문제: `dpkg -l`이 미설치 패키지도 exit 0 반환
   - 해결: `grep "^ii"` 추가로 실제 설치 여부 확인

6. **depends 단계 무시 문제**
   - 문제: `|| true`로 인해 의존성 설치 실패 무시
   - 해결: `|| status=$?`로 변경하여 오류 전파

7. **install 타이밍 문제**
   - 문제: configure 실행 후 파일 복사로 인해 파일 없음 오류
   - 해결: install 단계 직후 즉시 `installLibretroCore` 호출

8. **누락 파일 감지**
   - 문제: 필수 파일 없어도 경고만 하고 계속 진행
   - 해결: `installLibretroCore`에서 누락 파일 카운트 후 오류 반환

9. **특수 케이스 처리**
   - 문제: ScummVM 등 ROM Extensions 없는 코어
   - 해결: `get_special_core_info()` 함수로 특수 케이스 중앙 관리

### 13.6 작업 방식 및 규칙

#### RetroPie 스크립트 수정 금지 원칙

**절대 수정하지 않는 파일들:**
```
scriptmodules/retropie_setup/scriptmodules/**/*.sh
scriptmodules/retropie_setup/scriptmodules/**/패치파일
```

**대신 해야 할 일:**
- 호환 레이어 함수 추가/수정 (`ext_retropie_*.sh`)
- `packages.sh`에 로직 추가
- 특수 케이스는 `get_special_core_info()` 함수에 추가

#### 새로운 코어 추가 시

1. RetroPie 저장소에서 최신 스크립트 확인
2. 특별한 의존성이나 빌드 요구사항 확인
3. 테스트 빌드 수행
4. 오류 발생 시:
   - 호환 레이어에서 해결 가능한지 확인
   - 필요시 `get_special_core_info()`에 추가
   - GCC 버전 관련 문제는 `ext_retropie_env.sh` 수정

#### 디버깅 방법

로그 레벨 조정:
```bash
export LOG_LEVEL=0  # DEBUG 레벨
```

주요 로그 위치:
- `[INFO] (파일명:라인) 메시지` 형식
- `getDepends`: 의존성 설치 상세 로그
- `installLibretroCore`: 파일 복사 상세 로그
- `applyPatch`: 패치 적용 로그

#### 주의사항

1. **빌드 디렉토리 정리**
   - sources 단계에서 자동 정리됨
   - 수동 정리: `sudo rm -rf /tmp/retropangui/<module_id>`

2. **권한 문제**
   - 빌드는 sudo로 실행
   - 설치 파일은 자동으로 권한 조정
   - ROM/BIOS 디렉토리는 사용자 권한

3. **RetroPie 호환 환경 변수**
   - `md_id`: 모듈 ID
   - `md_build`: 빌드 디렉토리
   - `md_inst`: 설치 디렉토리
   - `md_data`: 데이터 디렉토리 (패치 등)
   - `md_ret_files`: 설치할 파일 목록
   - `md_ret_require`: 빌드 후 필수 파일

### 13.7 성공적으로 테스트된 코어

- ✅ lr-pcsx-rearmed (PlayStation)
- ✅ lr-mupen64plus (Nintendo 64)
- ✅ lr-np2kai (PC-98)
- ✅ lr-scummvm (ScummVM)

### 13.8 향후 확장

- 추가 libretro 코어 설치 지원
- emulators 타입 지원 (독립 에뮬레이터)
- ports 타입 지원 (포트 게임)
- 자동 업데이트 시스템

---

## 14. 스크립트 리팩토링 계획 (2025-11-04 추가)

### 14.1 리팩토링 목적

현재 스크립트 구조는 RetroPie 의존적이며, 일부 파일이 복잡도가 높아 유지보수가 어려운 상태입니다.
향후 **RetroPie 독립적인 RetroPangui 네이티브 시스템**으로 전환하기 위한 리팩토링이 필요합니다.

**주요 목표:**
1. **중복 함수 제거** - 동일 기능을 하는 함수가 여러 파일에 분산되어 있음
2. **복잡도 관리** - AI 및 개발자가 관리 가능한 파일 크기 및 역할 분리
3. **RetroPie 의존성 분리** - 호환 레이어와 네이티브 함수 명확히 구분
4. **모듈화 강화** - 코어/에뮬/RetroArch/ES 설치를 공통 함수로 처리

### 14.2 현재 문제점

#### 중복 함수

| 기능 | 파일 1 | 파일 2 | 비고 |
|------|--------|--------|------|
| INI 처리 | `inifuncs.sh` | `ext_retropie_ini.sh` | 완전 중복, 레거시 |
| Git 클론 | `func.sh::git_Pull_Or_Clone()` | `ext_retropie_inst.sh::gitPullOrClone()` | 비슷한 기능 |
| 코어 설치 | `ext_retropie_func.sh::installLibretroCore()` | `ext_retropie_inst.sh::installLibretroCore()` | 짧은 버전 vs 완전 버전 |
| ROM 디렉토리 | `packages.sh::mkRomDir()` | `ext_retropie_util.sh::mkRomDir()` | stub vs 실제 구현 |

#### 복잡한 파일

| 파일 | 줄 수 | 문제점 |
|------|------|--------|
| `ui.sh` | 606줄 | Dialog, 패키지 관리, 설정, 업데이트 등 역할 과다 |
| `func.sh` | 493줄 | Git, 사용자 관리, 설정, RetroArch 설치, 모듈 체크 등 혼재 |
| `packages.sh` | 393줄 | 모듈 설치/제거 + stub 함수 혼재 |
| `es_systems_updater.sh` | 329줄 | XML 조작 + 시스템 등록 혼재 |

#### 구조적 문제

```
현재: RetroPie 함수와 RetroPangui 함수가 명확히 분리 안 됨
미래: retropie_setup/ 제거 예정 → 독립적 구조 필요
```

### 14.3 새로운 디렉토리 구조 (2025-11-08 확정)

**설계 원칙:**
1. **compat/** - RetroPie 호환 레이어 (미래 제거 예정)
2. **lib/** - 작동 함수들 (설치/제거/파싱/로깅 등 모든 기능 함수)
3. **pkg/** - 설치할 패키지들 (RetroArch, EmulationStation, 기초 코어 등)
4. **ui/** - 사용자 인터페이스
5. **resources/** - 설정 파일 및 리소스

```
scriptmodules/
│
├── retropangui_setup.sh               # 진입점
├── config.sh                          # 환경 변수
│
├── resources/                         # 🟢 리소스 파일
│   └── priorities.conf                # 에뮬레이터 우선순위 설정
│
├── compat/                            # 🔴 RetroPie 호환 레이어 (미래 제거 예정)
│   ├── loader.sh                      # 호환 레이어 통합 로더 (ext_retropie_core.sh)
│   ├── env.sh                         # 환경 설정 (ext_retropie_env.sh)
│   ├── build.sh                       # 빌드 함수 (ext_retropie_inst.sh)
│   ├── registry.sh                    # 에뮬레이터 등록 (ext_retropie_op.sh)
│   ├── utils.sh                       # 유틸리티 (ext_retropie_util.sh)
│   └── packages.sh                    # RetroPie 패키지 관리 함수 (func.sh 분할)
│
├── lib/                               # 🟢 작동 함수들 (RetroPangui 네이티브)
│   ├── log.sh                         # 로깅 (helpers.sh)
│   ├── git.sh                         # Git 작업 (func.sh 분할)
│   ├── user.sh                        # 사용자/권한 (func.sh 분할)
│   ├── config_utils.sh                # 설정 파일 유틸리티 (func.sh 분할)
│   ├── retroarch_utils.sh             # RetroArch 유틸리티 (func.sh 분할)
│   ├── func.sh                        # 통합 로더 (분할된 네이티브 함수들을 source)
│   ├── ini.sh                         # INI 파싱 (inifuncs.sh)
│   ├── xml.sh                         # XML 조작 (es_systems_updater.sh)
│   ├── version.sh                     # 버전 관리 (version.sh)
│   ├── packages.sh                    # 패키지 관리 통합 로더 (install, remove, special 로드)
│   ├── install.sh                     # 설치 로직 (packages.sh install_module 분할)
│   ├── remove.sh                      # 제거 로직 (packages.sh remove_module 분할)
│   ├── special.sh                     # 특수 케이스 (packages.sh 분할)
│   ├── deps.sh                        # 의존성 설치 (install_base_1_in_5_deps.sh)
│   └── setup.sh                       # 환경 설정 (install_base_5_in_5_setup_env.sh)
│
├── pkg/                               # 🟢 설치할 패키지들
│   ├── system_install.sh              # Base System 통합 설치 스크립트
│   ├── retroarch.sh                   # RetroArch 패키지 (install_base_2_in_5_ra.sh)
│   ├── emulationstation.sh            # EmulationStation 패키지 (install_base_3_in_5_es.sh)
│   └── base_cores.sh                  # 기초 코어 묶음 (install_base_4_in_5_cores.sh)
│
└── ui/                                # 🟢 사용자 인터페이스
    └── menu.sh                        # 메뉴 로직 (ui.sh 이동, 향후 분할 예정)
```

**핵심 개선점:**
- **총 5개 폴더** (resources, compat, lib, pkg, ui) - 역할이 명확하게 분리
- **lib/ vs pkg/ 명확한 구분**: lib은 "작동 함수", pkg는 "설치할 패키지"
- **resources/ 추가**: 설정 파일 및 리소스를 별도 관리
- **중복 제거 완료**:
  - inifuncs.sh와 ext_retropie_ini.sh 통합
  - func.sh 완전 분할 (493줄 → 5개 모듈 + 19줄 로더)
    - lib/: 네이티브 함수 (git, user, config_utils, retroarch_utils)
    - compat/: RetroPie 호환 함수 (packages)
  - packages.sh 완전 분할 (393줄 → 3개 모듈 + 53줄 로더)
- **config.sh 최상위 이동**: 프로젝트 전체 설정을 루트에서 관리
- **lib/ vs compat/ 명확한 분리**: RetroPie 의존 함수는 compat/에만 위치

### 14.4 사용법 개선

**기존 방식:**
```bash
sudo ./retropangui_setup.sh install_module lr-pcsx-rearmed libretrocores
```

**개선된 방식 (타입 자동 감지):**
```bash
# 단일 패키지 설치
sudo ./retropangui_setup.sh install_module lr-pcsx-rearmed
sudo ./retropangui_setup.sh install_module retroarch
sudo ./retropangui_setup.sh install_module emulationstation

# 여러 패키지 한번에 설치
sudo ./retropangui_setup.sh install_module lr-pcsx-rearmed retroarch emulationstation
```

**자동 타입 감지 로직:**
- `lr-*` 파일명 → `libretrocores`에서 자동 탐색
- `retroarch`, `emulationstation` → 특별 케이스 처리
- 파일명 기반으로 타입 자동 결정

### 14.5 마이그레이션 전략

#### Phase 1: 폴더 구조 생성 (완료: 2025-11-08)
1. ✅ `resources/` 폴더 생성 및 `priorities.conf` 이동
2. ✅ `compat/` 폴더 생성 및 `ext_retropie_*.sh` 이동/정리
3. ✅ `lib/` 폴더 생성 및 작동 함수들 이동
4. ✅ `pkg/` 폴더 생성 및 `install_base_*.sh` 패키지 파일들 이동
5. ✅ `ui/` 폴더 생성 및 `ui.sh` → `ui/menu.sh` 이동
6. ✅ `config.sh` 최상위 폴더로 이동
7. ✅ `retropangui_setup.sh` 수정 (새 구조 반영)

#### Phase 2: 중복 제거 및 통합 (완료: 2025-11-08)
1. ✅ `inifuncs.sh`와 `ext_retropie_ini.sh` 통합 → `compat/ini.sh` 및 `lib/ini.sh`
2. ✅ `ext_retropie_func.sh` 제거 완료 (compat/ 폴더로 분산)
3. ✅ `func.sh` 분할 완료:
   - `lib/git.sh`: Git 관련 함수 (get_Git_Project_Dir_Name, git_Pull_Or_Clone, git_check_update)
   - `lib/user.sh`: 사용자 관련 함수 (get_effective_user, set_dir_ownership_and_permissions)
   - `lib/config_utils.sh`: 설정 파일 유틸리티 (config_set)
   - `lib/retroarch_utils.sh`: RetroArch 관련 함수 (create_runcommand_script, create_runcommand_config_script, install_ra_component)
   - `compat/packages.sh`: RetroPie 패키지 관리 함수 (is_module_installed, rp_checkModulePlatform, get_all_packages, get_packages_with_update_status)
   - `lib/func.sh`: 통합 로더 (네이티브 함수만 source)
4. ✅ `packages.sh` 분할 완료 → `lib/install.sh`, `lib/remove.sh`, `lib/special.sh`
5. ✅ `es_systems_updater.sh` 분할 완료 → `lib/xml.sh`

#### Phase 3: 독립화 (장기)
1. `compat/` 레이어 사용 최소화
2. 모든 기능을 RetroPangui 네이티브 함수로 전환
3. `retropie_setup/` 폴더 제거 또는 별도 저장소로 분리

### 14.6 작업 우선순위 (2025-11-08)

```
Phase 1 (완료: 2025-11-08):
✅ 1. [높음] 폴더 구조 생성 (resources, compat, lib, pkg, ui)
✅ 2. [높음] 기존 파일 이동 및 정리
✅ 3. [높음] retropangui_setup.sh 수정
✅ 4. [높음] config.sh 최상위 폴더로 이동

Phase 2 (완료: 2025-11-08):
✅ 5. [중간] 중복 함수 제거 및 통합
✅ 6. [중간] 복잡한 파일 분할 (func.sh, packages.sh)
   - func.sh → 5개 모듈 파일로 분할
     - lib/: git, user, config_utils, retroarch_utils, func (loader)
     - compat/: packages (RetroPie 호환 함수)
   - packages.sh → 3개 모듈 파일로 분할 (install, remove, special)

Phase 3 (장기):
7. [낮음] ui/menu.sh 분할 (dialog.sh, config.sh, menu.sh)
8. [낮음] RetroPie 의존성 완전 제거
```

### 14.7 주의사항

**절대 건드리지 않음:**
- `scriptmodules/retropie_setup/` 하위 모든 파일
  - 이 폴더는 코어/에뮬레이터 설치 스크립트만 참조용으로 사용
  - 미래에 제거하거나 별도 저장소로 분리 예정

**호환성 유지:**
- 기존 `retropangui_setup.sh` 진입점 변경 최소화
- 모든 환경 변수는 `config.sh`에서 관리
- 점진적 전환으로 기존 기능 유지

### 14.8 향후 작업

1. **함수 네이밍 컨벤션 확정**
   - `rpg_*` 접두사 사용 규칙 명확화
   - 일관성 있는 동사/명사 사용 (예: `install`, `create`, `check`, `get` 등)

2. **상세 리팩토링 계획 수립**
   - 파일별 함수 목록 및 이동 계획
   - 의존성 그래프 작성
   - 단계별 테스트 계획

3. **문서화**
   - 각 모듈의 역할 및 사용법
   - 함수 레퍼런스
   - 마이그레이션 가이드

---

## 15. 레거시 파일명 참조 (기록용)

2025-11-08 리팩토링으로 인해 다음 파일들이 새로운 구조로 이동되었습니다.
문서나 히스토리에서 이전 파일명을 참조할 경우 아래 매핑 정보를 참고하세요.

### 패키지 설치 스크립트

| 이전 파일명 (레거시) | 현재 파일명 | 비고 |
|---------------------|------------|------|
| `install_base_1_in_5_deps.sh` | `lib/deps.sh` | 의존성 설치 |
| `install_base_2_in_5_ra.sh` | `pkg/retroarch.sh` | RetroArch 설치 |
| `install_base_3_in_5_es.sh` | `pkg/emulationstation.sh` | EmulationStation 설치 + **테마 자동 설치 추가** |
| `install_base_4_in_5_cores.sh` | `pkg/base_cores.sh` | 기초 코어 묶음 |
| `install_base_5_in_5_setup_env.sh` | `lib/setup.sh` | 환경 설정 |

### 공통 함수 및 유틸리티

| 이전 파일명 (레거시) | 현재 파일명 | 비고 |
|---------------------|------------|------|
| `func.sh` (493줄) | **분할됨** | 아래 5개 파일로 분할 |
| ⤷ Git 관련 함수 | `lib/git.sh` | git_Pull_Or_Clone 등 |
| ⤷ 사용자/권한 함수 | `lib/user.sh` | set_dir_ownership_and_permissions 등 |
| ⤷ 설정 유틸리티 | `lib/config_utils.sh` | config_set 등 |
| ⤷ RetroArch 유틸리티 | `lib/retroarch_utils.sh` | create_runcommand_script 등 |
| ⤷ RetroPie 패키지 관리 | `compat/packages.sh` | is_module_installed 등 |
| `packages.sh` (393줄) | **분할됨** | 아래 3개 파일로 분할 |
| ⤷ 설치 로직 | `lib/install.sh` | install_module |
| ⤷ 제거 로직 | `lib/remove.sh` | remove_module |
| ⤷ 특수 케이스 | `lib/special.sh` | get_special_core_info |
| `es_systems_updater.sh` | `lib/xml.sh` | XML 조작 함수 |
| `helpers.sh` | `lib/log.sh` | 로깅 함수 |
| `inifuncs.sh` | `lib/ini.sh` (통합) | INI 파싱, ext_retropie_ini.sh와 통합 |
| `ui.sh` | `ui/menu.sh` | 메뉴 로직 |

### RetroPie 호환 레이어

| 이전 파일명 (레거시) | 현재 파일명 | 비고 |
|---------------------|------------|------|
| `ext_retropie_core.sh` | `compat/loader.sh` | 호환 레이어 통합 로더 |
| `ext_retropie_env.sh` | `compat/env.sh` | 환경 설정 |
| `ext_retropie_inst.sh` | `compat/build.sh` | 빌드 함수 |
| `ext_retropie_op.sh` | `compat/registry.sh` | 에뮬레이터 등록 |
| `ext_retropie_util.sh` | `compat/utils.sh` | 유틸리티 |
| `ext_retropie_ini.sh` | `lib/ini.sh` (통합) | INI 파싱, inifuncs.sh와 통합 |
| `ext_retropie_func.sh` | **제거됨** | compat/ 폴더로 분산 통합 |

### 설정 및 리소스

| 이전 위치 | 현재 위치 | 비고 |
|----------|----------|------|
| `scriptmodules/config.sh` | `config.sh` (루트) | 최상위로 이동 |
| `priorities.conf` (위치 미정) | `resources/priorities.conf` | 에뮬레이터 우선순위 |
| `resources/themes/` (프로젝트 루트) | `scriptmodules/resources/themes/` | 테마 리소스 |

---

**공지:** 문의 및 주요 변경시에는 반드시 본 문서에 주석 추가 후, 담당자 또는 GitHub Issue로 기록/공유 바랍니다.