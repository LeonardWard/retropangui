
# RetroPangui 프로젝트 핸드오버 문서

작성일자: 2025-10-31  
담당자: LeonardWard  
프로젝트 루트: `/home/pangui/scripts/retropangui/`  
핸드오버 세션: ES 멀티코어 지원, 자동화, 다국어 추가 완료 기준

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
    ├── packages.sh                    # 시스템/코어별 설치관리 및 자동등록 함수
    ├── install_base_1_in_5_deps.sh    # 1단계: 의존성 자동 설치
    ├── install_base_2_in_5_ra.sh      # 2단계: RetroArch 설치
    ├── install_base_3_in_5_es.sh      # 3단계: EmulationStation 소스 빌드 및 커스텀 설치
    ├── install_base_4_in_5_cores.sh   # 4단계: 코어별 설치 및 자동등록, es_systems.xml 관리
    ├── install_base_5_in_5_setup_env.sh # 5단계: 환경 셋업, 환경변수 자동 적용
    ├── es_systems_updater.sh          # 시스템 정의(XML), 코어 자동반영/권한복구 핵심모듈
    ├── helpers.sh                     # 로그 등 보조함수, 디버깅 서포트
    ├── func.sh                        # INI/환경 파싱, 메인 플로우 공통함수
    └── ...                            # 기타 서브모듈(상세 자동화, 확장/실험 코드 등)
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
3. **모든 변경을 원격(GitHub origin)에 직접 push하여 커밋/배포를 완료합니다.**
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

- **변경·수정 절차**
  1. **변경 이전**: 관련 모듈, 함수, config 파일, 자동화 로직을 모두 정독 및 이해.
  2. **설계 방안 검토**: 본래 방식·로직에 최대한 부합하는 형태로 개선/확장 방법 설계.
  3. **수정 및 적용**: 일관성을 유지하며, 기존 흐름에 맞게 신규 코드를 추가하거나 변경.
  4. **커밋 및 기록**: 모든 변경 내용은 커밋 메시지와 함께 인수인계 문서에 명확히 기록.
  5. **테스트 및 검증**: 수정 후 전체 기능 테스트로 기존 기능, 연동 모듈, 로그, 자동화 스크립트가 정상 작동하는지 확인.

- **핸드오버 문서 반영**
  - 모든 주요 변경사항(함수, 모듈, 프로세스, 설정파일 등)은 본 핸드오버 문서에 반드시 기록/주석 추가 또는 변경 이력에 반영
  - 신규 관리자는 추후 인수인계 시 위 절차와 정책을 지켜야 함

---

**공지:** 문의 및 주요 변경시에는 반드시 본 문서에 주석 추가 후, 담당자 또는 GitHub Issue로 기록/공유 바랍니다.