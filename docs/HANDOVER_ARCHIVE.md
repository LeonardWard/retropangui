# RetroPangui 프로젝트 개발 이력 아카이브

> **⚠️ 통합 아카이브 문서**
> 이 문서는 프로젝트 시작(2025-08)부터 2025-11-08까지의 전체 개발 이력을 보관한 통합 아카이브입니다.
> **더 이상 업데이트되지 않습니다.**
> 최신 핸드오버 정보는 [HANDOVER.md](HANDOVER.md)를 참조하세요.

---

**목차**
- [Part 1: 초기 개발 및 아키텍처 결정 (2025-08 ~ 2025-10-25)](#part-1-초기-개발-및-아키텍처-결정-2025-08--2025-10-25)
- [Part 2: 프로젝트 안정화 및 문서화 (2025-10-26)](#part-2-프로젝트-안정화-및-문서화-2025-10-26)
- [Part 3: 최신 개발 이력 (2025-10-26 ~ 2025-11-08)](#part-3-최신-개발-이력-2025-10-26--2025-11-08)

---


# Part 1: 초기 개발 및 아키텍처 결정 (2025-08 ~ 2025-10-25)

> 출처: `handover_retropangui.md` (작성일: 2025-10-25)

---

# RetroPangui Hnadover Doc

## 개요
- 프로젝트 이름 : Retro Pang-ui
- 개발 시작일 : 2025-8-22
- 담당자 : LeonardWard
- 프로젝트 루트 : /home/pangui/scripts/retropangui/
- 프로젝트 개요 : RetroArch, Emulationstation, Recalbox, Batocera, ES-DE, Retropie 등을 참고하여 독자적인 레트로게임 프론트앤드를 개발한다.

## 최종 목표: 독자적인 레트로게임 프론트엔드 개발

RetroPangui의 최종 목표는 기존의 여러 프로젝트를 참고하여, **독자적인 레트로게임 프론트엔드를 개발**하는 것입니다.

### 핵심 개발 전략: RetroPie EmulationStation(ES) 기반의 커스텀 버전 구축

이 독자적인 프론트엔드를 구축하기 위한 현재의 핵심 전략은 **RetroPie의 EmulationStation을 기반으로 커스텀 버전을 개발**하는 것입니다. 이는 안정성이 검증된 아키텍처 위에서 우리만의 독자적인 기능들을 통합하고 발전시켜 나가는 것을 목표로 합니다.

---

### **아키텍처 결정: Recalbox ES에서 RetroPie ES로 회귀하는 이유**

#### 1. Recalbox ES 전환 시도와 문제점
초기에는 RetroPie ES의 구조적 한계를 극복하고자 Recalbox ES로의 전환을 시도했습니다. Recalbox ES는 중앙 집중식 설정, 추상화된 입력 처리, 데이터 기반 UI 등 이론적으로는 더 유연한 아키텍처를 제공하는 것으로 보였습니다.

하지만 실제 개발 과정에서 Recalbox ES는 예상치 못한 문제점과 높은 복잡성을 드러냈습니다. 특히, RetroPangui의 독자적인 기능들을 통합하고 안정적으로 운영하는 데 있어 Recalbox ES의 특정 구조가 오히려 개발 효율성을 저해하고 안정성을 확보하기 어렵다는 결론에 도달했습니다.

#### 2. RetroPie ES로의 회귀 결정
Recalbox ES의 장점에도 불구하고, 현재 프로젝트의 목표와 개발 속도를 고려했을 때, 안정성이 검증되고 커스터마이징 경험이 축적된 RetroPie ES가 더 적합하다고 판단했습니다. RetroPie ES는 비록 일부 기능 구현 시 패치 작업이 필요할 수 있지만, 그 구조가 더 명확하고 제어하기 용이하여 RetroPangui의 독자적인 프론트엔드 개발에 더 안정적인 기반을 제공할 것입니다.

따라서, 프로젝트의 기반을 **RetroPie EmulationStation으로 회귀**하기로 결정했습니다. 이는 Recalbox ES의 잠재적 장점보다는 현재 프로젝트의 안정성과 개발 효율성을 우선시하는 전략적 선택입니다.

---

## 개발 워크플로우 및 규칙
- **읽기 전용 영역:** `retropie_setup` 디렉터리 하위의 파일은 RetroPie 원본으로 간주하며, 절대 직접 수정하지 않는다.
- **파일 길이 제한:** 스크립트 파일의 코드가 200줄을 넘어가기 시작하면, 유지보수성을 위해 기능 단위로 파일을 분리할 것을 고려한다.
- **디버깅 우선:** 문제가 발생하면, 섣불리 코드를 수정하기 전에 `log_msg`나 `ls -l` 같은 디버깅 코드를 추가하여 현상과 변수 값을 먼저 정확히 파악한다.
- **디버깅 코드 유지:** 추가된 디버깅 코드는 삭제하지 않는다. 최종적으로는 `log_msg`의 출력을 전역적으로 켜고 끌 수 있는(on/off) 기능을 구현하여 제어한다.(아직 미구현)
- **주석 수정/삭제 금지:** 주석은 수정/삭제하지 않는게 원칙이며 수정/삭제가 필요할 때는 사용자의 동의를 얻는다.

## 현재 아키텍처
/home/pangui/scripts/retropangui/
├── .git/                     # Git 버전 관리 디렉토리
├── .gitignore                # Git 제외 파일 목록
├── deburg_init_script.sh     # 디버그 초기화 스크립트
├── handover_retropangui.md   # 인수인계 문서
├── log/                      # 로그 디렉토리
├── resources/                # 리소스 파일(이미지, 아이콘 등) 디렉토리
├── retropangui_setup.sh      # 메인 진입(설치/실행) 스크립트
└── scriptmodules/            # 주요 기능별 스크립트 및 설정 디렉토리
    ├── config.sh                        # retropangui 환경 변수 설정
    ├── ext_retropie_core.sh             # 외부 RetroPie 코어 함수
    ├── ext_retropie_env.sh              # 외부 RetroPie 환경 변수 설정 함수
    ├── ext_retropie_func.sh             # 외부 RetroPie 기능 함수
    ├── ext_retropie_ini.sh              # 외부 RetroPie INI 처리 함수
    ├── ext_retropie_inst.sh             # 외부 RetroPie 설치 함수
    ├── ext_retropie_op.sh               # 외부 RetroPie 운영 함수
    ├── ext_retropie_util.sh             # 외부 RetroPie 유틸리티 함수
    ├── func.sh                          # retropangui 공통 기능 함수
    ├── helpers.sh                       # retropangui 설치관련 보조 함수(log 기능 함수 등)
    ├── inifuncs.sh                      # retropangui INI 파일 파싱 함수
    ├── install_base_1_in_5_deps.sh      # retropangui 1단계: 의존성 설치
    ├── install_base_2_in_5_ra.sh        # retropangui 2단계: RetroArch 설치
    ├── install_base_3_in_5_es.sh        # retropangui 3단계: EmulationStation 설치
    ├── install_base_4_in_5_cores.sh     # retropangui 4단계: 코어 빌드/설치
    ├── install_base_5_in_5_setup_env.sh # retropangui 5단계: 환경 세팅
    ├── packages.sh                      # 패키지 정의
    ├── recalbox/                        # Recalbox git copy 폴더
    ├── retroarch.init.cfg               # RetroArch 초기 설정 파일
    ├── retropie_setup/                  # RetroPie Setup git copy 폴더
    ├── system_install.sh                # 시스템 설치 메인 스크립트(source "$MODULES_DIR/install_base_*_in_5_*.sh")
    ├── systemlist.csv                   # retropangui 지원 시스템 목록 데이터
    └── ui.sh                            # retropangui UI(메뉴/인터페이스) 함수

## 주요 구현 내용 분석

### EmulationStation A/B 버튼 역할 고정 및 입력 처리 리팩토링
#### 1. 목표
- EmulationStation의 A/B 버튼 역할을 'B=확인(Accept)', 'A=취소(Back)'로 고정하고, 이 로직을 중앙 집중화하여 유지보수성을 높입니다.

#### 2. 기존 구현의 문제점: 분산된 입력 처리
- 기존 RetroPie ES에서는 '확인'과 '취소' 버튼의 역할이 각 UI 컴포넌트(파일)마다 개별적으로 `isMappedTo("a", ...)` 또는 `isMappedTo("b", ...)` 형태로 하드코딩되어 있었습니다.
- 이로 인해 A/B 버튼의 역할을 변경하려면 `es_swap_ab.patch`와 같이 20개 이상의 파일을 일일이 수정해야 하는 비효율적인 구조였습니다. 이는 유지보수를 어렵게 하고 새로운 버그를 유발할 가능성이 높았습니다.

#### 3. 개선된 구현: 의미 기반 입력 처리 중앙 집중화
- **핵심:** 물리적인 버튼(A, B) 대신 '확인(accept)'과 '취소(back)'와 같은 **의미 기반의 입력**을 사용하도록 변경합니다.
- **해결 방식:**
    - **`InputManager.cpp` 수정:** `InputManager::init()` 함수에서 모든 컨트롤러 및 키보드에 대해 물리적인 'B' 버튼을 의미론적인 'accept'에, 물리적인 'A' 버튼을 의미론적인 'back'에 매핑하도록 로직을 추가했습니다. 이제 버튼의 실제 역할은 `InputManager.cpp` 한 곳에서만 결정됩니다.
    - **UI 코드 리팩토링:** `es-app` 및 `es-core` 디렉터리 내의 모든 관련 파일에서 `isMappedTo("a", ...)` 호출을 `isMappedTo("back", ...)`으로, `isMappedTo("b", ...)` 호출을 `isMappedTo("accept", ...)`으로 변경했습니다.
    - **도움말 프롬프트 업데이트:** UI에 표시되는 도움말 프롬프트도 변경된 A/B 버튼 역할에 맞춰 '확인' 동작에는 'B' 버튼이, '취소' 동작에는 'A' 버튼이 표시되도록 수정했습니다.
- 이 개선을 통해 A/B 버튼 역할 변경 로직이 `InputManager.cpp` 한 곳으로 중앙 집중화되어, 향후 유지보수 및 변경이 훨씬 용이해졌습니다.

#### 4. 현재 상태 및 문제점

- **A/B 버튼 역할 고정 및 입력 처리 리팩토링 (진행 중):**
    - **목표:** EmulationStation의 A/B 버튼 역할을 'B=확인(Accept)', 'A=취소(Back)'로 고정하고, 이 로직을 중앙 집중화하여 유지보수성을 높이는 것입니다.
    - **기존 구현의 문제점:** 기존 RetroPie ES에서는 '확인'과 '취소' 버튼의 역할이 각 UI 컴포넌트(파일)마다 개별적으로 `isMappedTo("a", ...)` 또는 `isMappedTo("b", ...)` 형태로 하드코딩되어 있었습니다. 이로 인해 A/B 버튼의 역할을 변경하려면 `es_swap_ab.patch`와 같이 20개 이상의 파일을 일일이 수정해야 하는 비효율적인 구조였습니다.
    - **개선된 구현 (시도):** 물리적인 버튼(A, B) 대신 '확인(accept)'과 '취소(back)'와 같은 **의미 기반의 입력**을 사용하도록 변경하는 것을 목표로 했습니다.
        - **`InputManager.cpp` 수정:** `InputManager::init()` 함수에서 모든 컨트롤러 및 키보드에 대해 물리적인 'B' 버튼을 의미론적인 'accept'에, 물리적인 'A' 버튼을 의미론적인 'back'에 매핑하도록 로직을 추가했습니다.
            - **변경 내용:**
                ```
                // old_string
                    mCECInputConfig = new InputConfig(DEVICE_CEC, "CEC", CEC_GUID_STRING);
                    loadInputConfig(mCECInputConfig);
                }
                // new_string
                    mCECInputConfig = new InputConfig(DEVICE_CEC, "CEC", CEC_GUID_STRING);
                    loadInputConfig(mCECInputConfig);

                    // RetroPangui: Add semantic inputs for "accept" and "back"
                    LOG(LogInfo) << "Remapping A/B buttons to semantic inputs 'accept' and 'back'.";

                    // For each joystick...
                    for(auto it = mInputConfigs.begin(); it != mInputConfigs.end(); it++)
                    {
                        InputConfig* config = it->second;
                        Input a_input, b_input;
                        if(config->getInputByName("a", &a_input))
                            config->mapInput("back", a_input);
                        if(config->getInputByName("b", &b_input))
                            config->mapInput("accept", b_input);
                    }

                    // Also do it for the keyboard
                    Input kbd_a_input, kbd_b_input;
                    if(mKeyboardInputConfig->getInputByName("a", &kbd_a_input))
                        mKeyboardInputConfig->mapInput("back", kbd_a_input);
                    if(mKeyboardInputConfig->getInputByName("b", &kbd_b_input))
                        mKeyboardInputConfig->mapInput("accept", kbd_b_input);
                }
                ```
        - **UI 코드 리팩토링 (총 25개 파일, 44회 `replace` 작업):** `es-app` 및 `es-core` 디렉터리 내의 모든 관련 파일에서 `isMappedTo("a", ...)` 호출을 `isMappedTo("back", ...)`으로, `isMappedTo("b", ...)` 호출을 `isMappedTo("accept", ...)`으로 변경했습니다.
            - **변경 파일 및 내용:**
                - `es-core/src/components/ComponentList.h`: `isMappedTo("a", input)` -> `isMappedTo("accept", input)`
                - `es-core/src/components/OptionListComponent.h`: `isMappedTo("b", input)` -> `isMappedTo("back", input)`, `isMappedTo("a", input)` -> `isMappedTo("accept", input)`
                - `es-core/src/components/DateTimeEditComponent.cpp`: `isMappedTo("a", input)` -> `isMappedTo("accept", input)`, `isMappedTo("b", input)` -> `isMappedTo("back", input)`
                - `es-core/src/components/ButtonComponent.cpp`: `isMappedTo("a", input)` -> `isMappedTo("accept", input)`
                - `es-core/src/components/SwitchComponent.cpp`: `isMappedTo("a", input)` -> `isMappedTo("accept", input)`
                - `es-core/src/components/TextEditComponent.cpp`: `isMappedTo("a", input)` -> `isMappedTo("accept", input)`, `isMappedTo("b", input)` -> `isMappedTo("back", input)`
                - `es-core/src/guis/GuiTextEditPopup.cpp`: `isMappedTo("b", input)` -> `isMappedTo("back", input)`
                - `es-core/src/guis/GuiMsgBox.cpp`: `isMappedTo("b", input)` -> `isMappedTo("back", input)`
                - `es-core/src/guis/GuiInputConfig.cpp`: `isMappedTo("a", input)` -> `isMappedTo("accept", input)`
                - `es-app/src/components/ScraperSearchComponent.cpp`: `isMappedTo("a", input)` -> `isMappedTo("accept", input)`
                - `es-app/src/components/AsyncReqComponent.cpp`: `isMappedTo("b", input)` -> `isMappedTo("back", input)`
                - `es-app/src/components/RatingComponent.cpp`: `isMappedTo("a", input)` -> `isMappedTo("accept", input)`
                - `es-app/src/views/SystemView.cpp`: `isMappedTo("a", input)` -> `isMappedTo("accept", input)`
                - `es-app/src/views/gamelist/ISimpleGameListView.cpp`: `isMappedTo("a", input)` -> `isMappedTo("accept", input)`, `isMappedTo("b", input)` -> `isMappedTo("back", input)`
                - `es-app/src/SystemScreenSaver.cpp`: `isMappedTo("a", input)` -> `isMappedTo("accept", input)`
                - `es-app/src/guis/GuiGamelistOptions.cpp`: `isMappedTo("a", input)` -> `isMappedTo("accept", input)`, `isMappedTo("b", input)` -> `isMappedTo("back", input)`
                - `es-app/src/guis/GuiSettings.cpp`: `isMappedTo("b", input)` -> `isMappedTo("back", input)`
                - `es-app/src/guis/GuiGameScraper.cpp`: `isMappedTo("b", input)` -> `isMappedTo("back", input)`
                - `es-app/src/guis/GuiScreensaverOptions.cpp`: `isMappedTo("b", input)` -> `isMappedTo("back", input)`
                - `es-app/src/guis/GuiScraperStart.cpp`: `isMappedTo("b", input)` -> `isMappedTo("back", input)`
                - `es-app/src/guis/GuiGamelistFilter.cpp`: `isMappedTo("b", input)` -> `isMappedTo("back", input)`
                - `es-app/src/guis/GuiCollectionSystemsOptions.cpp`: `isMappedTo("b", input)` -> `isMappedTo("back", input)`
                - `es-app/src/guis/GuiMetaDataEd.cpp`: `isMappedTo("b", input)` -> `isMappedTo("back", input)`
                - `es-app/src/guis/GuiMenu.cpp`: `isMappedTo("b", input)` -> `isMappedTo("back", input)`
                - `es-app/src/guis/GuiRandomCollectionOptions.cpp`: `isMappedTo("b", input)` -> `isMappedTo("back", input)`
        - **도움말 프롬프트 업데이트 (총 12개 파일, 18회 `replace` 작업):** UI에 표시되는 도움말 프롬프트도 변경된 A/B 버튼 역할에 맞춰 '확인' 동작에는 'B' 버튼이, '취소' 동작에는 'A' 버튼이 표시되도록 수정했습니다.
            - **변경 파일 및 내용:**
                - `es-core/src/components/ButtonComponent.cpp`: `HelpPrompt("a", ...)` -> `HelpPrompt("b", ...)`
                - `es-core/src/components/SwitchComponent.cpp`: `HelpPrompt("a", ...)` -> `HelpPrompt("b", ...)`
                - `es-core/src/components/TextEditComponent.cpp`: `HelpPrompt("b", "stop editing")` -> `HelpPrompt("a", "stop editing")`, `HelpPrompt("a", "edit")` -> `HelpPrompt("b", "edit")`
                - `es-core/src/guis/GuiTextEditPopup.cpp`: `HelpPrompt("b", "back")` -> `HelpPrompt("a", "back")`
                - `es-core/src/components/ImageComponent.cpp`: `HelpPrompt("a", "select")` -> `HelpPrompt("b", "select")`
                - `es-core/src/components/VideoComponent.cpp`: `HelpPrompt("a", "select")` -> `HelpPrompt("b", "select")`
                - `es-app/src/components/ScraperSearchComponent.cpp`: `HelpPrompt("a", "accept result")` -> `HelpPrompt("b", "accept result")`
                - `es-app/src/components/AsyncReqComponent.cpp`: `HelpPrompt("b", "cancel")` -> `HelpPrompt("a", "cancel")`
                - `es-app/src/components/RatingComponent.cpp`: `HelpPrompt("a", "add star")` -> `HelpPrompt("b", "add star")`
                - `es-app/src/views/SystemView.cpp`: `HelpPrompt("a", "select")` -> `HelpPrompt("b", "select")`
                - `es-app/src/views/UIModeController.cpp`: `case 'a': out += "A";` -> `case 'a': out += "B";`, `case 'b': out += "B";` -> `case 'b': out += "A";`
                - `es-app/src/views/gamelist/BasicGameListView.cpp`: `HelpPrompt("a", "launch")` -> `HelpPrompt("b", "launch")`, `HelpPrompt("b", "back")` -> `HelpPrompt("a", "back")`
                - `es-app/src/views/gamelist/GridGameListView.cpp`: `HelpPrompt("a", "launch")` -> `HelpPrompt("b", "launch")`, `HelpPrompt("b", "back")` -> `HelpPrompt("a", "back")`
                - `es-app/src/guis/GuiGamelistOptions.cpp`: `HelpPrompt("b", "close")` -> `HelpPrompt("a", "close")`
                - `es-app/src/guis/GuiSettings.cpp`: `HelpPrompt("b", "back")` -> `HelpPrompt("a", "back")`
                - `es-app/src/guis/GuiScreensaverOptions.cpp`: `HelpPrompt("b", "back")` -> `HelpPrompt("a", "back")`
                - `es-app/src/guis/GuiScraperStart.cpp`: `HelpPrompt("b", "back")` -> `HelpPrompt("a", "back")`
                - `es-app/src/guis/GuiGamelistFilter.cpp`: `HelpPrompt("b", "back")` -> `HelpPrompt("a", "back")`
                - `es-app/src/guis/GuiCollectionSystemsOptions.cpp`: `HelpPrompt("b", "back")` -> `HelpPrompt("a", "back")`
                - `es-app/src/guis/GuiMetaDataEd.cpp`: `HelpPrompt("b", "back")` -> `HelpPrompt("a", "back")`
                - `es-app/src/guis/GuiMenu.cpp`: `HelpPrompt("a", "select")` -> `HelpPrompt("b", "select")`
                - `es-app/src/guis/GuiRandomCollectionOptions.cpp`: `HelpPrompt("b", "back")` -> `HelpPrompt("a", "back")`
        - **`develop_custom_es.sh` 스크립트 수정:**
            - **바꾼 것:** `apt-get update` 및 `apt-get install` 명령어에 `sudo`를 추가하여 권한 문제를 해결했습니다.
                ```
                // old_string (apt-get update)
                        apt-get update || { log_msg ERROR "apt-get update 실패"; return 1; }
                // new_string (apt-get update)
                        sudo apt-get update || { log_msg ERROR "apt-get update 실패"; return 1; }

                // old_string (apt-get install)
                        apt-get install -y "${missing_packages[@]}" || { log_msg ERROR "패키지 설치 실패"; return 1; }
                // new_string (apt-get install)
                        sudo apt-get install -y "${missing_packages[@]}" || { log_msg ERROR "패키지 설치 실패"; return 1; }
                ```
            - **바꾼 것:** `run_dev_emulationstation` 함수에서 EmulationStation 바이너리 경로를 수정했습니다.
                ```
                // old_string
                    local binary="$DEV_ES_BUILD_DIR/build/emulationstation"
                // new_string
                    local binary="$DEV_ES_BUILD_DIR/emulationstation"
                ```
    - **바꾼 뒤의 상황:**
        - `InputManager.cpp` 수정 후 EmulationStation 재빌드 시 컴파일 오류가 발생했습니다.
        - 오류 메시지는 `error: qualified-id in declaration before ‘(’ token` 및 `error: expected ‘}’ at end of input` 이었습니다. 이는 `InputManager::init()` 함수 내 닫는 중괄호(`}`)가 중복되어 발생한 구문 오류로 파악되었습니다.
        - 이 컴파일 오류로 인해 EmulationStation의 빌드가 실패했습니다.
        - `develop_custom_es.sh` 스크립트의 `run_dev_emulationstation` 함수에서 EmulationStation 바이너리 경로를 `"$DEV_ES_BUILD_DIR/build/emulationstation"`에서 `"$DEV_ES_BUILD_DIR/emulationstation"`으로 수정하여 빌드된 바이너리를 찾지 못하는 문제를 해결했습니다.
    - **사용자가 느끼는 간극:**
        - 리팩토링된 EmulationStation 빌드 후 실행 시, 'A'와 'B' 버튼을 포함한 **모든 버튼이 작동하지 않는 문제**가 보고되었습니다.
        - 이는 EmulationStation의 핵심 기능인 입력 처리가 완전히 마비되어, 사용자가 시스템을 전혀 조작할 수 없는 심각한 상황입니다.

- **문제 진단 및 미해결 원인:**
    - 컴파일 오류는 `InputManager.cpp`의 `init()` 함수에 불필요한 닫는 중괄호가 추가되어 발생한 것으로, `replace` 도구의 `old_string` 불일치로 인해 자동 복구 및 재적용에 실패했습니다. 현재 `InputManager.cpp`는 컴파일 오류 상태로 남아있습니다.
    - 버튼 미작동 문제의 정확한 원인은 아직 파악되지 않았습니다. 문제 진단을 위해 `InputManager.cpp`에 디버그 로그를 추가하여 입력 매핑 과정을 추적하려 했으나, 사용자 요청으로 인해 디버그 로그 추가 작업이 중단되었습니다.
    - `es_input.cfg` 파일의 내용을 확인한 결과, 컨트롤러의 'a', 'b' 버튼 매핑 정보는 정상적으로 존재함이 확인되었습니다.
    - 현재로서는 `InputManager`의 재매핑 로직 자체의 결함, `InputConfig`의 새로운 의미 기반 입력 처리 방식, 또는 `InputConfig::isMappedTo` 함수의 내부 동작 방식 등 여러 가능성이 존재합니다.
    - **향후 과제:** `InputManager.cpp`의 컴파일 오류를 먼저 해결하고, 이후 `InputManager`의 디버그 로그를 활성화하여 입력 이벤트의 흐름과 매핑 상태를 면밀히 분석하는 것이 시급합니다.
---

### **시스템 설정 파일(`es_systems.cfg`) 생성 방식**

#### 1. 최종 목표
- 중앙 데이터베이스(`systemlist.csv`)를 기반으로, 현재 아키텍처(RetroPie ES)에 맞는 `es_systems.cfg` 파일을 동적으로 생성합니다.

#### 2. 최종 구현: RetroPie 방식 (`runcommand` 런처)
- **핵심:** RetroPie는 `runcommand.sh`라는 중앙 런처를 통해 게임을 실행하여, 사용자가 시스템별 기본 에뮬레이터를 쉽게 변경할 수 있는 유연성을 제공합니다.
- **구현 내용:**
    - **`generate_es_systems_cfg_from_csv()` 함수:**
        - **역할:** RetroPie 방식에 맞는 `es_systems.cfg`를 생성합니다.
        - **동작:** `<command>` 태그에 실제 에뮬레이터가 아닌, `runcommand.sh`를 호출하는 명령어를 기록합니다.
    - **`create_runcommand_script()` 함수:**
        - **역할:** 게임 실행 시 `emulators.cfg`를 참조하여 최종 에뮬레이터를 결정하는 `runcommand.sh` 스크립트 자체를 생성합니다.
- 이 함수들은 현재 RetroPie 기반의 메인 플로우에서 사용됩니다.

#### 3. 레거시 구현 (참고용): Recalbox 방식 (직접 실행)
- **핵심:** Recalbox ES는 `runcommand.sh`와 같은 중간 런처 스크립트를 사용하지 않습니다. `es_systems.cfg`의 `<command>` 태그에 에뮬레이터(RetroArch)를 직접 실행하는 명령어가 포함되어야 합니다.
- **구현 내용:**
    - **`generate_es_systems_cfg_from_csv_recalbox()` 함수 (신규):**
        - **위치:** `func.sh`
        - **역할:** Recalbox 방식에 맞는 `es_systems.cfg`를 생성하는 새로운 전용 함수입니다.
        - **동작:** `systemlist.csv`에서 시스템별 최적 코어 정보를 찾은 후, `<command>` 태그를 다음과 같은 **직접 실행** 형식으로 생성합니다.
          ```
          <command>/opt/retropangui/bin/retroarch -L /opt/retropangui/libretro/cores/snes9x_libretro.so %ROM%</command>
          ```
    - **`install_base_3_in_5_es.sh` 수정:** ES 설치 스크립트가 이 새로운 `_recalbox` 버전의 함수를 호출하도록 수정했습니다.
- 이 방식은 현재 사용되지 않습니다.

---

### EmulationStation ShowFolders 기능 구현

#### 1. 목표
- 게임 폴더 표시 방식을 사용자가 선택할 수 있도록 하여, 멀티디스크 게임이나 단일 게임 폴더의 표시를 제어합니다.
- RetroPie 공식 EmulationStation에서 지원하던 `ShowFolders` 기능이 누락되어 있어 이를 구현합니다.

#### 2. 기존 문제점
- RetroPie ES에서 `ShowFolders` 옵션이 `es_settings.cfg`에 저장은 되지만, 실제 소스 코드에서 이를 처리하는 로직이 없어 동작하지 않음
- PSX 등 멀티디스크 게임의 경우 폴더 구조를 사용하는데, 폴더 표시 방식을 제어할 수 없어 불편함
- 사용자가 단일 게임만 있는 폴더를 건너뛰고 바로 게임을 보고 싶어도 방법이 없음

#### 3. 구현 내용

**3.1 Settings.cpp: ShowFolders 설정 추가**
```cpp
// es-core/src/Settings.cpp
mStringMap["ShowFolders"] = "always";  // 기본값: 모든 폴더 표시
```

**3.2 GuiMenu.cpp: UI Settings에 메뉴 옵션 추가**
- 위치: `[Main Menu] > [UI SETTINGS] > [SHOW FOLDERS]`
- 옵션:
  - `always` - 모든 폴더 표시 (기본값)
  - `never` - 폴더를 숨기고 내부 게임들만 직접 표시
  - `having multiple games` - 단일 게임 폴더만 건너뛰고, 여러 게임이 있는 폴더는 표시
- 설정 변경 시 `ViewController::get()->reloadAll()` 호출하여 즉시 반영

**3.3 FileData.cpp: 폴더 필터링 로직 구현**
- `getChildrenListToDisplay()` 메서드에서 ShowFolders 설정에 따라 폴더를 필터링
- 동작 방식:
  - `"always"`: 모든 폴더를 정상적으로 표시
  - `"never"`: 폴더를 건너뛰고 폴더 내부의 게임들을 직접 상위 레벨에 표시
  - `"having multiple games"`: 폴더의 게임 개수를 확인하여:
    - 1개만 있으면: 폴더를 건너뛰고 게임만 표시
    - 2개 이상: 폴더를 정상적으로 표시

**핵심 코드:**
```cpp
const std::vector<FileData*>& FileData::getChildrenListToDisplay() {
    std::string showFoldersSetting = Settings::getInstance()->getString("ShowFolders");
    bool needsFolderFiltering = (showFoldersSetting == "never" ||
                                  showFoldersSetting == "having multiple games");

    if (idx->isFiltered() || needsFolderFiltering) {
        mFilteredChildren.clear();
        for(auto child : mChildren) {
            if (needsFolderFiltering && child->getType() == FOLDER) {
                size_t childCount = child->getChildrenByFilename().size();

                if (showFoldersSetting == "never") {
                    // 폴더의 모든 자식을 직접 추가
                    for(auto grandchild : child->getChildren()) {
                        mFilteredChildren.push_back(grandchild);
                    }
                    continue;
                }
                else if (showFoldersSetting == "having multiple games" && childCount == 1) {
                    // 단일 게임만 추가
                    mFilteredChildren.push_back(child->getChildren()[0]);
                    continue;
                }
            }
            mFilteredChildren.push_back(child);
        }
        return mFilteredChildren;
    }
    return mChildren;
}
```

#### 4. 빌드 스크립트 개선
**문제:** 초기 빌드 시 패치가 제대로 반영되지 않는 문제 발생
- 원인: `make clean`만으로는 CMake 캐시가 남아있어 변경사항이 제대로 반영되지 않음

**해결:** `install_base_3_in_5_es.sh` 수정
```bash
# 변경 전
mkdir -p "$ES_BUILD_DIR/build"
cd "$ES_BUILD_DIR/build"
cmake ..
make clean
make -j$(nproc)

# 변경 후
rm -rf "$ES_BUILD_DIR/build"  # 완전히 삭제
mkdir -p "$ES_BUILD_DIR/build"
cd "$ES_BUILD_DIR/build"
cmake ..
make -j$(nproc)  # make clean 제거
```

이제 빌드 디렉토리를 완전히 재생성하므로 패치가 항상 확실히 반영됨

#### 5. 적용된 파일
- **패치 파일:** `resources/patches/es_showfolders.patch`
- **적용 위치:** `scriptmodules/install_base_3_in_5_es.sh`
```bash
patch -p1 -d "$ES_BUILD_DIR" < "$RESOURCES_DIR/patches/es_showfolders.patch"
```

#### 6. 동작 확인
- ✅ 세 가지 옵션 모두 정상 작동
- ✅ 설정 변경 후 즉시 반영 (ES 재시작 불필요)
- ✅ 게임 실행 정상
- ✅ 기존 필터 기능과 호환

#### 7. 사용 사례
- **PSX 멀티디스크 게임:** `"having multiple games"` 설정 시 `Final Fantasy VII (K)` 폴더(3개 디스크)는 표시되지만, `.m3u` 파일만 있는 폴더는 자동으로 숨겨짐
- **단일 ROM 폴더 정리:** `"never"` 설정 시 모든 폴더가 숨겨지고 게임만 깔끔하게 표시됨
- **전통적인 방식:** `"always"` 설정 시 기존과 동일하게 모든 폴더 표시

---

## 해결 완료 과제 히스토리

### `install_base_4_in_5_cores.sh` 스크립트 코어 오류 발생 해결 과정
- **원인:** 커스텀 `iniConfig` 함수의 불안정성 및 코어별 `install` 함수 호출 누락으로 `md_ret_files` 배열이 비어있었음.
- **해결:** RetroPie 원본의 `ini*` 함수로 교체하고, `install` 함수 호출 로직을 추가하여 해결.

### sed 오류 및 경로 문제
- **원인:** 커스텀 `iniProcess` 함수 내 `sed` 명령어 버그 및 `addEmulator` 등 커스텀 헬퍼 함수의 불안정성.
- **해결:** 문제가 되는 `ext_retropie_ini.sh`와 `ext_retropie_op.sh`를 RetroPie 원본의 안정적인 코드로 교체하여 해결.

### Recalbox 설정 구조 분석 (ES 메뉴 및 시스템 정의)
- **결론:** Recalbox는 `system.ini` -> Python 스크립트 -> `systemlist.xml` -> C++ 내부 객체로 이어지는 복잡하고 체계적인 파이프라인을 통해 시스템을 정의함을 파악. 이 분석을 통해 `retropangui`에 맞는 시스템 정의 구현의 기반을 마련해야함.

---

## 작업 이력

### 2025-10-23~25: EmulationStation 논리 버튼 매핑 완전 구현 (완료)

#### 배경
- 기존 `es_swap_ab.patch`는 단순히 코드에서 "a"와 "b"를 swap하는 방식으로 구현
- 문제점:
  - 조이패드 물리 매핑(`es_input.cfg`)과 충돌 → 이중 swap 발생
  - 20개 이상 파일을 수정해야 하는 비효율적 구조
  - Start/Select 등 다른 버튼의 역할이 불명확
  - 사용자가 버튼 레이아웃을 선택할 수 없음

#### 해결 방안: 논리 버튼 매핑
- **핵심 개념:** 물리 버튼(a, b)과 논리 동작(accept, back)을 분리
- **구현 위치:**
  - `InputConfig.h/cpp`: 논리 매핑 관리 함수 추가
  - `Settings.cpp`: ButtonLayout 기본값 추가 (nintendo)
  - `GuiMenu.cpp`: UI SETTINGS에 버튼 레이아웃 선택 메뉴 추가
  - **24개 UI 컴포넌트 파일**: 모든 버튼 입력 처리 로직 변경

#### 구현 내용

**1. InputConfig 인프라 구축 (InputConfig.h/cpp)**
```cpp
// es-core/src/InputConfig.h
bool isMappedToAction(const std::string& action, Input input);
static void setButtonLayout(const std::string& layout);
static std::string getButtonLayout();
static std::string getActionButton(const std::string& action);
static void initActionMapping();

// Private members
static std::map<std::string, std::string> sActionMapping;
static std::string sButtonLayout;
```

**2. 논리 매핑 초기화 로직 (InputConfig.cpp)**
```cpp
void InputConfig::initActionMapping()
{
    std::string layout = Settings::getInstance()->getString("ButtonLayout");
    if (layout.empty())
        layout = "nintendo";

    if (layout == "nintendo")
    {
        sActionMapping["accept"] = "b";  // B버튼 = 확인
        sActionMapping["back"] = "a";    // A버튼 = 취소
    }
    else if (layout == "sony" || layout == "xbox")
    {
        sActionMapping["accept"] = "a";  // A버튼 = 확인
        sActionMapping["back"] = "b";    // B버튼 = 취소
    }

    sButtonLayout = layout;
    LOG(LogInfo) << "Button Layout: " << layout;
}

bool InputConfig::isMappedToAction(const std::string& action, Input input)
{
    if (sActionMapping.empty() || sButtonLayout.empty())
        initActionMapping();

    auto it = sActionMapping.find(action);
    if (it != sActionMapping.end())
        return isMappedTo(it->second, input);

    return isMappedTo(action, input);
}
```

**3. Settings 추가 (Settings.cpp)**
```cpp
// RetroPangui: Button Layout (nintendo, sony, xbox)
mStringMap["ButtonLayout"] = "nintendo";
```

**4. UI 메뉴 추가 (GuiMenu.cpp)**
- 위치: `[메인 메뉴] > [UI SETTINGS] > [BUTTON LAYOUT]`
- 옵션:
  - `nintendo` - Nintendo 스타일 (B=확인, A=취소)
  - `sony` - Sony/Xbox 스타일 (A=확인, B=취소)
  - `xbox` - Sony/Xbox 스타일 (A=확인, B=취소)

**5. 전체 UI 컴포넌트 리팩토링 (24개 파일)**

모든 `isMappedTo("a", input)` → `isMappedToAction("accept", input)` 변경
모든 `isMappedTo("b", input)` → `isMappedToAction("back", input)` 변경

**수정된 파일 목록:**

*es-core/src/components:*
- TextEditComponent.cpp (accept/back)
- SwitchComponent.cpp (accept)
- OptionListComponent.h (accept/back)
- DateTimeEditComponent.cpp (accept/back)
- ComponentList.h (accept)
- ButtonComponent.cpp (accept)

*es-core/src/guis:*
- GuiTextEditPopup.cpp (back)
- GuiMsgBox.cpp (back)

*es-app/src/views/gamelist:*
- ISimpleGameListView.cpp (accept/back)

*es-app/src/views:*
- SystemView.cpp (accept)

*es-app/src/guis:*
- GuiGamelistOptions.cpp (accept/back)
- GuiMenu.cpp (back)
- GuiSettings.cpp (back)
- GuiScreensaverOptions.cpp (back)
- GuiScraperStart.cpp (back)
- GuiRandomCollectionOptions.cpp (back)
- GuiMetaDataEd.cpp (back)
- GuiGamelistFilter.cpp (back)
- GuiGameScraper.cpp (back)
- GuiCollectionSystemsOptions.cpp (back)

*es-app/src/components:*
- ScraperSearchComponent.cpp (accept)
- RatingComponent.cpp (accept)
- AsyncReqComponent.cpp (back)

*es-app/src:*
- SystemScreenSaver.cpp (accept)

#### 적용 방식
- **RetroPangui EmulationStation 포크에 직접 반영**
- GitHub 저장소: https://github.com/LeonardWard/retropangui-emulationstation
- 브랜치: main
- 더 이상 패치 파일 방식 사용하지 않음 (Git으로 직접 관리)

#### 빌드 스크립트 변경
```bash
# scriptmodules/install_base_3_in_5_es.sh
# 기존 패치 적용 제거
# patch -p1 -d "$ES_BUILD_DIR" < "$RESOURCES_DIR/patches/es_logical_button_mapping.patch"

# ES 저장소에서 main 브랜치 직접 사용
cd "$ES_BUILD_DIR" && git checkout main && git pull
```

#### 테스트 완료
- ✅ Nintendo 스타일 (B=확인, A=취소) 정상 작동
- ✅ Sony/Xbox 스타일 (A=확인, B=취소) 정상 작동
- ✅ 설정 변경 후 즉시 적용
- ✅ 모든 UI 컴포넌트에서 버튼 입력 정상
- ✅ 게임 실행/종료 정상
- ✅ 메뉴 네비게이션 정상

#### 검증 (2025-10-25)
- 사용자 피드백: "ㅇㅋ 버튼 멀쩡하게 작동 하고.."
- 커밋 및 GitHub 푸시 완료

#### 특이사항
- **Start 버튼:** 항상 메뉴 열기 (변경 없음)
- **Select 버튼:** 컨텍스트별 기능 (변경 없음)
- **X, Y 버튼:** 향후 필요시 논리 매핑 추가 가능
- **HelpPrompt 미변경:** 화면 하단 도움말은 물리 버튼 표시 유지 (향후 개선 가능)

---

### 2025-10-24: EmulationStation 멀티코어 지원 구현 (Recalbox 스타일)

#### 배경
- 기존 RetroPie 방식: `runcommand.sh` 중간 스크립트를 통한 간접 실행
- 문제점:
  - 런처 스크립트 오버헤드
  - 복잡한 실행 플로우 (ES → runcommand.sh → RetroArch)
  - 시스템별 여러 코어 지원이 `emulators.cfg`에 의존
  - 코어별 RetroArch 설정 오버라이드 지원 필요

#### 목표: Recalbox 스타일 멀티코어 아키텍처
- **핵심:** ES에서 직접 RetroArch를 실행 (runcommand.sh 제거)
- **멀티코어:** 하나의 시스템에 여러 코어 정의, 우선순위 기반 자동 선택
- **설정 관리:** 시스템별/코어별 RetroArch 설정 파일 오버라이드
- **동적 경로:** 하드코딩 제거, Settings API 기반 경로 관리

#### 주요 변경사항

**1. es_systems.cfg → es_systems.xml 전환**
- XML 형식 채택 이유:
  - 데이터/로직 분리 (Recalbox 방식)
  - 복잡한 계층 구조 표현 용이 (멀티코어 지원)
  - VSCode 등 IDE의 자동완성/문법검사 지원
- 파일명 변경: `es_systems.cfg` → `es_systems.xml`
- 모든 관련 코드에서 파일 경로 수정 완료

**2. SystemData.h: CoreInfo 구조체 추가**
```cpp
// es-app/src/SystemData.h
// RetroPangui: Multi-core support
struct CoreInfo
{
    std::string name;              // 코어 이름 (예: "pcsx_rearmed")
    int priority;                  // 우선순위 (낮을수록 높은 우선순위)
    std::vector<std::string> extensions;  // 코어별 지원 확장자
};

struct SystemEnvironmentData
{
    std::string mStartPath;
    std::vector<std::string> mSearchExtensions;
    std::string mLaunchCommand;
    std::vector<PlatformIds::PlatformId> mPlatformIds;
    // RetroPangui: Store multiple cores for this system
    std::vector<CoreInfo> mCores;
};
```

**3. SystemData.cpp: 멀티코어 파싱 로직**
```cpp
// es-app/src/SystemData.cpp - loadSystem() 함수
// RetroPangui: Parse cores if available
std::vector<CoreInfo> cores;
pugi::xml_node coresNode = system.child("cores");
if (coresNode)
{
    for (pugi::xml_node coreNode = coresNode.child("core"); coreNode; coreNode = coreNode.next_sibling("core"))
    {
        CoreInfo coreInfo;
        coreInfo.name = coreNode.attribute("name").as_string();
        coreInfo.priority = coreNode.attribute("priority").as_int(999);

        // Parse core-specific extensions
        std::string coreExtensions = coreNode.attribute("extensions").as_string();
        if (!coreExtensions.empty())
        {
            std::vector<std::string> coreExtList = readList(coreExtensions.c_str());
            for (auto& ext : coreExtList)
            {
                if (!ext.empty())
                    coreInfo.extensions.push_back(ext);
            }
        }

        if (!coreInfo.name.empty())
        {
            cores.push_back(coreInfo);
            LOG(LogInfo) << "  Core: " << coreInfo.name << " (priority: " << coreInfo.priority << ")";
        }
    }

    // Sort cores by priority (lower number = higher priority)
    std::sort(cores.begin(), cores.end(), [](const CoreInfo& a, const CoreInfo& b) {
        return a.priority < b.priority;
    });
}

// Modified validation to allow empty command when cores exist
if (name.empty() || path.empty() || extensions.empty() || (cmd.empty() && cores.empty()))
{
    LOG(LogError) << "System \"" << name << "\" is missing name, path, extension, or command/cores!";
    return nullptr;
}
```

**4. FileData.cpp: 동적 RetroArch 명령 생성**
```cpp
// es-app/src/FileData.cpp - launchGame() 함수
#include "Settings.h"  // 추가

// RetroPangui: If cores are defined and command is empty, build command from settings
if (!mEnvData->mCores.empty() && command.empty())
{
    const CoreInfo& defaultCore = mEnvData->mCores[0]; // Already sorted by priority
    std::string systemName = mSystem->getName();

    std::string retroarchPath = Settings::getInstance()->getString("RetroArchPath");
    std::string coresPath = Settings::getInstance()->getString("LibretroCoresPath");
    std::string configPath = Settings::getInstance()->getString("CoreConfigPath");

    command = retroarchPath + " -L " + coresPath + "/" + defaultCore.name + "_libretro.so " +
              "--config " + configPath + "/" + systemName + "/retroarch.cfg %ROM%";

    LOG(LogInfo) << "Using core: " << defaultCore.name << " (priority: " << defaultCore.priority << ")";
}
```

**5. Settings.cpp: 경로 설정 변수 추가**
```cpp
// es-core/src/Settings.cpp - setDefaults() 함수
// RetroPangui: Paths for multi-core support
mStringMap["RetroArchPath"] = "/opt/retropangui/bin/retroarch";
mStringMap["LibretroCoresPath"] = "/opt/retropangui/libretro/cores";
mStringMap["CoreConfigPath"] = "/home/pangui/share/system/configs/cores";
```

**6. es_systems_generator.sh: XML 생성 함수**
```bash
# scriptmodules/es_systems_generator.sh
generate_es_systems_xml_multi_core() {
    local src_csv="$1"
    local dest_xml="$2"

    echo '<?xml version="1.0"?>' | sudo tee "$dest_xml" > /dev/null
    echo "<systemList>" | sudo tee -a "$dest_xml" > /dev/null

    # systemlist.csv 파싱하여 시스템별 코어 정보 생성
    # 출력 형식:
    # <system>
    #     <name>psx</name>
    #     <fullname>PlayStation</fullname>
    #     <path>~/RetroPie/roms/psx</path>
    #     <extension>.bin .cue .img .mdf .pbp .toc .cbn .m3u .ccd .chd .zip .7z</extension>
    #     <command></command>  <!-- 비어있음 - 멀티코어 사용 -->
    #     <cores>
    #         <core name="pcsx_rearmed" priority="2" extensions=".bin .cue .img"/>
    #         <core name="beetle_psx" priority="3" extensions=".cue .chd"/>
    #     </cores>
    #     <platform>psx</platform>
    #     <theme>psx</theme>
    # </system>
}
```

**7. install_base_3_in_5_es.sh: 패치 적용**
```bash
# 패치 적용
patch -p1 -d "$ES_BUILD_DIR" < "$RESOURCES_DIR/patches/es_multi_core_support.patch"

# es_systems.xml 생성 (runcommand.sh 방식 대신)
source "$MODULES_DIR/es_systems_generator.sh"
generate_es_systems_xml_multi_core "$MODULES_DIR/systemlist.csv" "$ES_SYSTEMS_PATH"
```

#### es_systems.xml 예제 구조
```xml
<?xml version="1.0"?>
<systemList>
  <system>
    <name>psx</name>
    <fullname>PlayStation</fullname>
    <path>~/RetroPie/roms/psx</path>
    <extension>.bin .cue .img .mdf .pbp .toc .cbn .m3u .ccd .chd .zip .7z</extension>
    <command></command>
    <cores>
      <core name="pcsx_rearmed" priority="2" extensions=".bin .cue .img"/>
      <core name="beetle_psx" priority="3" extensions=".cue .chd"/>
    </cores>
    <platform>psx</platform>
    <theme>psx</theme>
  </system>
</systemList>
```

#### 실행 플로우
1. **ES 시작:** `es_systems.xml` 로드 → CoreInfo 파싱 → priority 기준 정렬
2. **게임 선택:** FileData가 게임 확장자와 코어 extensions 비교
3. **명령 생성:** Settings에서 경로 읽기 → RetroArch 명령 동적 조립
4. **실행:** 직접 RetroArch 호출 (중간 스크립트 없음)

#### 실제 실행 로그 (PSX 테스트)
```
[LogInfo] Using core: pcsx_rearmed (priority: 2)
[LogInfo] /opt/retropangui/bin/retroarch -L /opt/retropangui/libretro/cores/pcsx_rearmed_libretro.so --config /home/pangui/share/system/configs/cores/psx/retroarch.cfg "/home/pangui/RetroPie/roms/psx/Klonoa - Door to Phantomile (Korea).chd"
[LogInfo] Game ended: 2025-10-24 (약 12분간 플레이 후 정상 종료)
```

#### 적용된 파일
- **패치 파일:** `resources/patches/es_multi_core_support.patch` (174줄)
- **수정된 ES 소스:**
  - `es-app/src/SystemData.h` - CoreInfo 구조체 추가
  - `es-app/src/SystemData.cpp` - 멀티코어 파싱 및 검증 로직
  - `es-app/src/FileData.cpp` - 동적 명령 생성
  - `es-core/src/Settings.cpp` - 경로 설정 추가
- **신규 스크립트:**
  - `scriptmodules/es_systems_generator.sh` - XML 생성 함수
- **수정된 스크립트:**
  - `scriptmodules/install_base_3_in_5_es.sh` - 패치 적용 로직

#### 검증 완료
- ✅ ES 정상 빌드 및 실행
- ✅ es_systems.xml 파싱 성공
- ✅ 멀티코어 정보 로드 (로그 확인)
- ✅ PSX 게임 직접 실행 (runcommand.sh 우회)
- ✅ RetroArch 설정 오버라이드 적용
- ✅ 게임 플레이 및 종료 정상

#### 향후 작업 (미완료)
1. **메뉴 구조 재구성:**
   - MAIN MENU → GAME SETTINGS / UI SETTINGS / SYSTEM SETTINGS
   - GAME SETTINGS > CORE SETTINGS > 시스템별 코어 선택 UI
   - 기존 메뉴 항목들 재배치 (SCRAPER, SOUND, INPUT 등)

2. **코어 선택 UI 구현:**
   - 사용자가 시스템별 선호 코어 선택 가능하도록
   - 선택한 코어를 Settings에 저장 (`PreferredCore_psx` 등)
   - FileData.cpp에서 사용자 선택 코어 우선 확인 후 priority 적용

3. **확장자별 코어 매칭:**
   - CoreInfo의 extensions 활용하여 파일 확장자별 최적 코어 자동 선택
   - 예: `.chd` 파일은 `beetle_psx` 우선, `.bin` 파일은 `pcsx_rearmed` 우선

4. **최종 패치 업데이트:**
   - 메뉴 변경사항 포함
   - git diff로 최신 패치 재생성

#### 기술적 의의
- **아키텍처 통합:** Recalbox의 직접 실행 방식 + RetroPie의 안정성
- **유지보수성:** Settings 기반 경로 관리로 하드코딩 제거
- **확장성:** 새 시스템/코어 추가 시 XML만 수정하면 됨
- **성능:** 중간 스크립트 제거로 실행 지연 최소화
- **일관성:** 코어별 RetroArch 설정을 시스템별 디렉토리로 명확히 분리

---

## 현재 진행중
- EmulationStation 멀티코어 지원 구현 (2025-10-24) - 핵심 기능 완료
  - 다음 단계: 메뉴 재구성 및 코어 선택 UI 추가
- RetroPie ES 기반의 빌드 스크립트 및 설정 생성 로직 안정화 작업 진행 중
- 스크린샷 시스템 추가
- RA 설정 시스템 추가
- 나머지 BASE 코어 정상 빌드

# 완료된 작업

## 1. GitHub 포크 생성 (2025-10-24)
- 저장소: https://github.com/LeonardWard/retropangui-emulationstation
- 브랜치: main
- RetroPie EmulationStation을 기반으로 독자적인 포크 생성

## 2. EmulationStation 주요 기능 구현

### 2.1 멀티코어 지원 (2025-10-24) ✅
- ✅ runcommand.sh 제거, RetroArch 직접 실행
- ✅ es_systems.xml 형식 (기존 .cfg 대체)
- ✅ Settings 기반 동적 경로 관리
- ✅ 시스템별 여러 코어 정의 및 우선순위 지원
- ✅ CoreInfo 구조체 및 파싱 로직 구현
- ✅ PSX 게임 실행 검증 완료

### 2.2 ShowFolders 기능 (2025-10-24) ✅
- ✅ 폴더 표시 방식 3가지 옵션 구현
  - `always`: 모든 폴더 표시
  - `never`: 폴더 숨기고 게임만 표시
  - `having multiple games`: 단일 게임 폴더만 건너뛰기
- ✅ FileData.cpp 필터링 로직 구현
- ✅ GuiMenu.cpp UI 메뉴 추가
- ✅ 설정 변경 시 즉시 반영 (ES 재시작 불필요)

### 2.3 논리 버튼 매핑 (2025-10-23~25) ✅
- ✅ InputConfig 인프라 구축 (isMappedToAction)
- ✅ ButtonLayout 설정 추가 (nintendo/sony/xbox)
- ✅ GuiMenu UI 메뉴 추가
- ✅ **24개 UI 컴포넌트 파일 전체 리팩토링 완료**
- ✅ 모든 버튼 입력 처리를 논리 매핑으로 전환
- ✅ Nintendo/Sony/Xbox 스타일 모두 정상 작동 검증

### 2.4 다국어 지원 (2025-10-24) ✅
- ✅ 언어 선택 기능 (영어/한국어)
- ✅ LocaleES 시스템 구현
- ✅ 한글 폰트 Fallback 지원
- ✅ GuiMenu 주요 메뉴 한글 번역 (80+ 항목)
- ✅ CMakeLists.txt에 locale 컴파일 추가
- ✅ 언어 변경 시 ES 재시작 메시지 표시

## 3. 빌드 시스템 통합 ✅
- ✅ config.sh: ES_GIT_URL을 포크 저장소로 변경
- ✅ install_base_3_in_5_es.sh: 패치 파일 제거, Git 직접 관리로 전환
- ✅ locale 파일 자동 설치 추가
- ✅ 빌드 디렉토리 완전 재생성으로 캐시 문제 해결
- ✅ 빌드 성공
- ✅ 실행 정상
- ✅ 게임 실행 정상

## 4. 개발 워크플로우 개선 ✅
- ✅ 패치 파일 방식에서 Git 직접 관리로 전환
- ✅ Git으로 버전 관리
- ✅ 직접 ES 소스 수정 가능
- ✅ upstream 업데이트 merge 가능
- ✅ 개발 효율성 및 유지보수성 향상

## 5. 검증 완료 (2025-10-25)
- ✅ ShowFolders 3가지 옵션 모두 정상 작동
- ✅ 논리 버튼 매핑 Nintendo/Sony/Xbox 스타일 정상 작동
- ✅ 언어 전환 정상 (영어 ↔ 한국어)
- ✅ 멀티코어 시스템 (PSX) 게임 실행 정상
- ✅ 모든 UI 네비게이션 정상
- ✅ 사용자 피드백: "ㅇㅋ 버튼 멀쩡하게 작동 하고.."

---

## 📝 향후 개선 사항 (선택사항)

### 1. 언어 번역 확장
- 더 많은 UI 텍스트에 _() 매크로 적용
- 일본어, 중국어 등 추가 언어 지원

### 2. 메뉴 재구성
- GAME SETTINGS / UI SETTINGS / SYSTEM SETTINGS 구조로 재편
- 코어 선택 UI 추가 (시스템별 선호 코어 설정)

### 3. HelpPrompt 동적 표시
- 화면 하단 도움말을 버튼 레이아웃에 맞춰 동적으로 표시
- 현재는 물리 버튼 표시 유지

### 4. 패치 파일 정리
- resources/patches/es_*.patch 파일들을 legacy/ 폴더로 이동
- 더 이상 패치 방식을 사용하지 않으므로 정리 필요

### 5. 문서화
- README.md 작성
- 설치 가이드
- 개발자 가이드

---

# Part 2: 프로젝트 안정화 및 문서화 (2025-10-26)

> 출처: `README.md.bak` (작성일: 2025-10-26)

---

# RetroPangui

**독자적인 레트로게임 프론트엔드 플랫폼**

[![Version](https://img.shields.io/badge/version-0.9.2-blue.svg)](https://github.com/LeonardWard/retropangui)
[![Platform](https://img.shields.io/badge/platform-Linux-lightgrey.svg)](https://www.linux.org/)
[![License](https://img.shields.io/badge/license-GPL--3.0-green.svg)](LICENSE)

---

## 목차

- [프로젝트 개요](#프로젝트-개요)
- [아키텍처](#아키텍처)
- [주요 기능](#주요-기능)
- [시스템 모듈](#시스템-모듈)
- [EmulationStation 커스터마이징](#emulationstation-커스터마이징)
- [멀티코어 시스템](#멀티코어-시스템)
- [5단계 자동 설치](#5단계-자동-설치)
- [패키지 관리 시스템](#패키지-관리-시스템)
- [지원 시스템](#지원-시스템)
- [시스템 요구사항](#시스템-요구사항)
- [설치 가이드](#설치-가이드)
- [사용 가이드](#사용-가이드)
- [디렉토리 구조](#디렉토리-구조)
- [개발 현황](#개발-현황)
- [로드맵](#로드맵)
- [트러블슈팅](#트러블슈팅)
- [기여하기](#기여하기)
- [라이선스](#라이선스)
- [크레딧](#크레딧)

---

## 프로젝트 개요

### 소개

RetroPangui는 Linux 환경에서 동작하는 통합 레트로게임 프론트엔드 플랫폼입니다.
### 핵심 목표

1. **독자적인 프론트엔드 개발**
   - RetroPie EmulationStation을 기반으로 하되, 독자적인 기능 통합
   - Git 기반 포크 관리로 upstream 업데이트 병합 가능
   - 패치 파일 방식 제거, 직접 소스 코드 관리

2. **멀티코어 아키텍처 구현**
   - Recalbox 방식의 시스템당 다중 코어 지원
   - 우선순위 기반 자동 코어 선택
   - 확장자별 코어 매칭
   - 사용자 선호 코어 설정 (향후 구현)

3. **직접 실행 방식 채택**
   - runcommand.sh 중간 스크립트 제거
   - RetroArch 직접 호출로 실행 지연 최소화
   - Settings API 기반 동적 경로 관리

4. **완전 자동화 시스템**
   - 의존성부터 환경 구성까지 5단계 자동 설치
   - 패키지별 개별 설치 지원
   - 플랫폼 자동 감지 및 최적화

5. **사용자 친화적 인터페이스**
   - 논리 버튼 매핑으로 다양한 컨트롤러 레이아웃 지원
   - 다국어 지원 (현재 영어/한국어)
   - 직관적인 WhipTail 기반 TUI

### 개발 정보

| 항목 | 내용 |
|------|------|
| 프로젝트 이름 | RetroPangui (Retro Pang-ui) |
| 개발 시작일 | 2025년 8월 22일 |
| 현재 버전 | v0.9.2 |
| 개발 단계 | v1.0 런칭 준비 |
| 담당자 | LeonardWard |
| 프로젝트 루트 | /home/pangui/scripts/retropangui/ |
| GitHub 저장소 | https://github.com/LeonardWard/retropangui |
| ES 포크 저장소 | https://github.com/LeonardWard/retropangui-emulationstation |
| 라이선스 | GPL-3.0 |

---

## 아키텍처

### 전체 아키텍처

RetroPangui는 다음과 같은 계층 구조로 설계되었습니다:

```
┌─────────────────────────────────────────────────────────┐
│                     사용자 인터페이스                    │
│  ┌─────────────────┐         ┌─────────────────┐        │
│  │ EmulationStation│         │  WhipTail TUI   │        │
│  │   (프론트엔드)   │         │ (설치/관리)     │        │
│  └────────┬────────┘         └────────┬────────┘        │
└───────────┼───────────────────────────┼─────────────────┘
            │                           │
┌───────────┼───────────────────────────┼─────────────────┐
│           │      설정 및 관리 계층    │                 │
│  ┌────────▼────────┐         ┌────────▼────────┐        │
│  │ es_systems.xml  │         │ retropangui     │        │
│  │ es_settings.cfg │         │ _setup.sh       │        │
│  │ es_input.cfg    │         │ (메인 스크립트)  │        │
│  └────────┬────────┘         └────────┬────────┘        │
└───────────┼───────────────────────────┼─────────────────┘
            │                           │
┌───────────┼───────────────────────────┼─────────────────┐
│           │      코어 관리 계층       │                 │
│  ┌────────▼────────┐         ┌────────▼────────┐        │
│  │ CoreInfo        │         │ systemlist.csv  │        │
│  │ (멀티코어 정보)  │         │ (중앙 DB)       │        │
│  └────────┬────────┘         └────────┬────────┘        │
└───────────┼───────────────────────────┼─────────────────┘
            │                           │
┌───────────┼───────────────────────────┼─────────────────┐
│           │      실행 계층            │                 │
│  ┌────────▼────────┐         ┌────────▼────────┐        │
│  │   RetroArch     │         │  Libretro Cores │        │
│  │  (에뮬레이터)    │         │  (코어 바이너리) │        │
│  └─────────────────┘         └─────────────────┘        │
└─────────────────────────────────────────────────────────┘
```

### 실행 플로우

#### EmulationStation 게임 실행 플로우

```
1. EmulationStation 시작
   ↓
2. es_systems.xml 로드
   - <system> 태그 파싱
   - <cores> 태그 파싱 → CoreInfo 구조체 생성
   - priority 기준으로 코어 정렬
   ↓
3. 사용자가 게임 선택
   ↓
4. FileData::launchGame() 호출
   ↓
5. 게임 확장자 확인
   ↓
6. CoreInfo의 extensions와 매칭
   - 매칭되는 코어 중 priority가 가장 낮은(우선순위 높은) 코어 선택
   ↓
7. Settings API에서 경로 읽기
   - RetroArchPath: /opt/retropangui/bin/retroarch
   - LibretroCoresPath: /opt/retropangui/libretro/cores
   - CoreConfigPath: ~/share/system/configs/cores
   ↓
8. RetroArch 명령어 동적 생성
   command = retroarchPath + " -L " + coresPath + "/" +
             coreName + "_libretro.so --config " +
             configPath + "/" + systemName + "/retroarch.cfg %ROM%"

   예시:
   /opt/retropangui/bin/retroarch \
     -L /opt/retropangui/libretro/cores/pcsx_rearmed_libretro.so \
     --config ~/share/system/configs/cores/psx/retroarch.cfg \
     "/home/pangui/share/roms/psx/game.cue"
   ↓
9. fork() 및 exec()로 RetroArch 직접 실행
   ↓
10. 게임 플레이
   ↓
11. RetroArch 종료 후 EmulationStation으로 복귀
```

#### 5단계 자동 설치 플로우

```
retropangui_setup.sh 실행
   ↓
config.sh 소싱 → 전역 환경 변수 설정
   ↓
main_ui() 실행 → WhipTail 메뉴 표시
   ↓
"1. Base System 설치" 선택
   ↓
system_install.sh 소싱
   ↓
┌─────────────────────────────────────────┐
│ 1단계: install_base_1_in_5_deps.sh     │
│  - apt-get update && upgrade            │
│  - BUILD_DEPS 배열 순회                 │
│  - 각 패키지 설치 확인 및 설치          │
└─────────────────────────────────────────┘
   ↓
┌─────────────────────────────────────────┐
│ 2단계: install_base_2_in_5_ra.sh       │
│  - RetroArch git clone                  │
│  - ./configure --prefix=/opt/retropangui│
│  - make -j$(nproc) && make install      │
│  - assets/shaders/overlays 설치        │
└─────────────────────────────────────────┘
   ↓
┌─────────────────────────────────────────┐
│ 3단계: install_base_3_in_5_es.sh       │
│  - ES 포크 git clone                    │
│  - CMake 빌드                           │
│  - generate_es_systems_xml() 호출      │
│  - locale 파일 복사                     │
└─────────────────────────────────────────┘
   ↓
┌─────────────────────────────────────────┐
│ 4단계: install_base_4_in_5_cores.sh    │
│  - systemlist.csv 파싱                  │
│  - 각 코어별 install_module 호출        │
│    - depends → sources → build →        │
│      install → configure                │
└─────────────────────────────────────────┘
   ↓
┌─────────────────────────────────────────┐
│ 5단계: install_base_5_in_5_setup_env.sh│
│  - ~/share 하위 디렉토리 생성           │
│  - 권한 및 소유권 설정                  │
│  - 시스템별 config 디렉토리 생성        │
└─────────────────────────────────────────┘
   ↓
설치 완료
```

### 설계 전략

#### RetroPie EmulationStation 기반 선택 이유

RetroPangui는 RetroPie EmulationStation을 기반으로 커스텀 버전을 구축합니다. 이는 다음과 같은 이유에서입니다:

1. **안정성 검증**: RetroPie ES는 수년간의 개발과 커뮤니티 테스트를 거친 안정적인 코드베이스
2. **명확한 구조**: 비교적 단순하고 이해하기 쉬운 아키텍처
3. **커스터마이징 용이**: 패치 적용 및 기능 추가가 상대적으로 쉬움
4. **빌드 시스템 활용**: RetroPie-Setup의 강력한 빌드 시스템 재사용 가능

#### Recalbox 요소 통합

Recalbox의 다음 요소들을 선택적으로 통합했습니다:

1. **멀티코어 시스템**: 시스템당 다중 코어 정의 및 우선순위 관리
2. **직접 실행 방식**: runcommand.sh 제거, RetroArch 직접 호출
3. **XML 기반 시스템 정의**: es_systems.xml 형식 채택

#### 독자적인 개선사항

RetroPangui만의 독자적인 개선사항:

1. **논리 버튼 매핑 시스템**: 물리 버튼과 논리 동작 분리
2. **Settings API 기반 경로 관리**: 하드코딩 제거
3. **패키지 관리 시스템**: 개별 코어/에뮬레이터 선택 설치
4. **중앙 데이터베이스**: systemlist.csv 기반 통합 관리

---

## 주요 기능

### 1. 멀티코어 시스템

#### 개요

하나의 게임 시스템에 여러 에뮬레이터 코어를 정의하고, 우선순위와 확장자에 따라 자동으로 최적의 코어를 선택하는 시스템입니다.

#### 핵심 구성요소

**1) es_systems.xml 형식**

기존 RetroPie의 `.cfg` 형식 대신 XML 형식을 채택했습니다.

**XML 형식 채택 이유:**
- 계층 구조 표현 용이 (시스템 > 코어 관계)
- 멀티코어 정보를 명확하게 정의 가능
- VSCode 등 IDE의 자동완성/문법검사 지원
- 확장성 (새로운 속성 추가 용이)

**예시 (PSX):**
```xml
<?xml version="1.0"?>
<systemList>
  <system>
    <name>psx</name>
    <fullname>PlayStation</fullname>
    <path>~/RetroPie/roms/psx</path>
    <extension>.bin .cue .img .mdf .pbp .toc .cbn .m3u .ccd .chd .zip .7z</extension>
    <command></command>  <!-- 비어있음: 멀티코어 사용 -->
    <cores>
      <core name="pcsx_rearmed" priority="2" extensions=".bin .cue .img"/>
      <core name="beetle_psx" priority="3" extensions=".cue .chd"/>
      <core name="swanstation" priority="4" extensions=".ccd .chd .cue .m3u .pbp .toc"/>
    </cores>
    <platform>psx</platform>
    <theme>psx</theme>
  </system>
</systemList>
```

**2) CoreInfo 구조체**

`es-app/src/SystemData.h`에 정의된 구조체:

```cpp
struct CoreInfo
{
    std::string name;                      // 코어 이름 (예: "pcsx_rearmed")
    int priority;                          // 우선순위 (낮을수록 높은 우선순위)
    std::vector<std::string> extensions;   // 코어별 지원 확장자
};

struct SystemEnvironmentData
{
    std::string mStartPath;
    std::vector<std::string> mSearchExtensions;
    std::string mLaunchCommand;
    std::vector<PlatformIds::PlatformId> mPlatformIds;
    std::vector<CoreInfo> mCores;  // 멀티코어 정보
};
```

**3) 파싱 로직 (SystemData.cpp)**

```cpp
// loadSystem() 함수 내부
std::vector<CoreInfo> cores;
pugi::xml_node coresNode = system.child("cores");

if (coresNode)
{
    for (pugi::xml_node coreNode = coresNode.child("core");
         coreNode;
         coreNode = coreNode.next_sibling("core"))
    {
        CoreInfo coreInfo;
        coreInfo.name = coreNode.attribute("name").as_string();
        coreInfo.priority = coreNode.attribute("priority").as_int(999);

        std::string coreExtensions = coreNode.attribute("extensions").as_string();
        if (!coreExtensions.empty())
        {
            std::vector<std::string> coreExtList = readList(coreExtensions.c_str());
            for (auto& ext : coreExtList)
            {
                if (!ext.empty())
                    coreInfo.extensions.push_back(ext);
            }
        }

        if (!coreInfo.name.empty())
        {
            cores.push_back(coreInfo);
            LOG(LogInfo) << "  Core: " << coreInfo.name
                         << " (priority: " << coreInfo.priority << ")";
        }
    }

    // priority 기준 정렬 (낮을수록 먼저)
    std::sort(cores.begin(), cores.end(),
              [](const CoreInfo& a, const CoreInfo& b) {
                  return a.priority < b.priority;
              });
}
```

**4) 동적 명령 생성 (FileData.cpp)**

```cpp
// launchGame() 함수 내부
if (!mEnvData->mCores.empty() && command.empty())
{
    const CoreInfo& defaultCore = mEnvData->mCores[0];  // priority 정렬됨
    std::string systemName = mSystem->getName();

    std::string retroarchPath = Settings::getInstance()->getString("RetroArchPath");
    std::string coresPath = Settings::getInstance()->getString("LibretroCoresPath");
    std::string configPath = Settings::getInstance()->getString("CoreConfigPath");

    command = retroarchPath + " -L " + coresPath + "/" + defaultCore.name +
              "_libretro.so --config " + configPath + "/" + systemName +
              "/retroarch.cfg %ROM%";

    LOG(LogInfo) << "Using core: " << defaultCore.name
                 << " (priority: " << defaultCore.priority << ")";
}
```

**5) Settings 기반 경로 관리 (Settings.cpp)**

```cpp
// setDefaults() 함수 내부
// RetroPangui: Paths for multi-core support
mStringMap["RetroArchPath"] = "/opt/retropangui/bin/retroarch";
mStringMap["LibretroCoresPath"] = "/opt/retropangui/libretro/cores";
mStringMap["CoreConfigPath"] = "/home/pangui/share/system/configs/cores";
```

#### 코어 선택 알고리즘

**현재 구현 (v0.9.2):**

1. es_systems.xml 로드 시 CoreInfo 배열 생성
2. priority 기준 오름차순 정렬
3. 게임 실행 시 배열의 첫 번째 코어(priority 가장 낮음) 자동 선택

**향후 개선 (v1.0+):**

1. 게임 확장자와 CoreInfo.extensions 매칭
2. 사용자 선호 코어 설정 확인 (Settings::PreferredCore_<system>)
3. 위 조건들을 종합하여 최적 코어 선택

#### 기술적 장점

1. **성능 최적화**
   - runcommand.sh 중간 스크립트 제거
   - fork/exec 오버헤드 최소화
   - 직접 실행으로 약 0.5~1초 실행 시간 단축

2. **유연성**
   - 시스템별 여러 코어 지원
   - 코어별 지원 확장자 정의
   - 우선순위 기반 자동 선택

3. **확장성**
   - 새 코어 추가 시 XML만 수정
   - 코드 변경 불필요
   - 동적 경로 관리로 이식성 향상

4. **관리 용이성**
   - 시스템별/코어별 RetroArch 설정 분리
   - 중앙 집중식 설정 관리
   - 명확한 설정 파일 계층 구조

### 2. 논리 버튼 매핑 시스템

#### 개요

물리적 버튼(A, B)과 논리적 동작(확인, 취소)을 완전히 분리하여, 다양한 컨트롤러 레이아웃을 지원하는 시스템입니다.

#### 배경 및 문제점

**기존 RetroPie ES의 문제:**
- '확인'과 '취소' 버튼의 역할이 각 UI 컴포넌트마다 개별적으로 하드코딩됨
- A/B 버튼 역할 변경을 위해 20개 이상의 파일을 일일이 수정해야 함
- `es_swap_ab.patch` 방식: 유지보수 어렵고 버그 유발 가능성 높음
- 조이패드 물리 매핑(`es_input.cfg`)과 충돌하여 이중 swap 발생

**RetroPangui의 해결책:**
- 물리 버튼(a, b)과 논리 동작(accept, back)을 완전히 분리
- `InputConfig` 클래스에서 중앙 집중식 관리
- 사용자가 메뉴에서 레이아웃 선택 가능
- 모든 UI 컴포넌트 리팩토링으로 일관성 확보

#### 핵심 구현

**1) InputConfig 클래스 확장 (es-core/src/InputConfig.h)**

```cpp
class InputConfig
{
public:
    // 기존 함수들...

    // RetroPangui: 논리 버튼 매핑 관련 함수
    bool isMappedToAction(const std::string& action, Input input);
    static void setButtonLayout(const std::string& layout);
    static std::string getButtonLayout();
    static std::string getActionButton(const std::string& action);
    static void initActionMapping();

private:
    // 정적 멤버: 모든 InputConfig 인스턴스가 공유
    static std::map<std::string, std::string> sActionMapping;
    static std::string sButtonLayout;
};
```

**2) 논리 매핑 초기화 (es-core/src/InputConfig.cpp)**

```cpp
std::map<std::string, std::string> InputConfig::sActionMapping;
std::string InputConfig::sButtonLayout;

void InputConfig::initActionMapping()
{
    std::string layout = Settings::getInstance()->getString("ButtonLayout");
    if (layout.empty())
        layout = "nintendo";  // 기본값

    if (layout == "nintendo")
    {
        sActionMapping["accept"] = "b";  // B버튼 = 확인
        sActionMapping["back"] = "a";    // A버튼 = 취소
    }
    else if (layout == "sony" || layout == "xbox")
    {
        sActionMapping["accept"] = "a";  // A버튼 = 확인
        sActionMapping["back"] = "b";    // B버튼 = 취소
    }

    sButtonLayout = layout;
    LOG(LogInfo) << "Button Layout initialized: " << layout;
}

bool InputConfig::isMappedToAction(const std::string& action, Input input)
{
    // 매핑이 초기화되지 않았으면 초기화
    if (sActionMapping.empty() || sButtonLayout.empty())
        initActionMapping();

    // action에 해당하는 물리 버튼 찾기
    auto it = sActionMapping.find(action);
    if (it != sActionMapping.end())
        return isMappedTo(it->second, input);

    // 매핑되지 않은 action은 기존 방식 사용
    return isMappedTo(action, input);
}
```

**3) Settings 추가 (es-core/src/Settings.cpp)**

```cpp
void Settings::setDefaults()
{
    // 기존 설정들...

    // RetroPangui: Button Layout (nintendo, sony, xbox)
    mStringMap["ButtonLayout"] = "nintendo";
}
```

**4) UI 메뉴 추가 (es-app/src/guis/GuiMenu.cpp)**

```cpp
// UI SETTINGS 메뉴 내부
auto button_layout = std::make_shared<OptionListComponent<std::string>>(
    mWindow, "BUTTON LAYOUT", false);

button_layout->add("NINTENDO (B=확인, A=취소)", "nintendo",
                   Settings::getInstance()->getString("ButtonLayout") == "nintendo");
button_layout->add("SONY (A=확인, B=취소)", "sony",
                   Settings::getInstance()->getString("ButtonLayout") == "sony");
button_layout->add("XBOX (A=확인, B=취소)", "xbox",
                   Settings::getInstance()->getString("ButtonLayout") == "xbox");

s->addWithLabel("BUTTON LAYOUT", button_layout);
s->addSaveFunc([button_layout] {
    Settings::getInstance()->setString("ButtonLayout", button_layout->getSelected());
    InputConfig::initActionMapping();  // 즉시 재초기화
});
```

**5) UI 컴포넌트 리팩토링 (24개 파일)**

**변경 전:**
```cpp
if (config->isMappedTo("a", input))  // 물리 버튼 직접 참조
{
    // 확인 동작
}
```

**변경 후:**
```cpp
if (config->isMappedToAction("accept", input))  // 논리 동작 참조
{
    // 확인 동작
}
```

**수정된 파일 목록:**

*es-core/src/components:*
- ButtonComponent.cpp: accept
- SwitchComponent.cpp: accept
- OptionListComponent.h: accept, back
- DateTimeEditComponent.cpp: accept, back
- ComponentList.h: accept
- TextEditComponent.cpp: accept, back

*es-core/src/guis:*
- GuiTextEditPopup.cpp: back
- GuiMsgBox.cpp: back
- GuiInputConfig.cpp: accept

*es-app/src/views:*
- SystemView.cpp: accept

*es-app/src/views/gamelist:*
- ISimpleGameListView.cpp: accept, back

*es-app/src/guis:*
- GuiGamelistOptions.cpp: accept, back
- GuiMenu.cpp: back
- GuiSettings.cpp: back
- GuiScreensaverOptions.cpp: back
- GuiScraperStart.cpp: back
- GuiGameScraper.cpp: back
- GuiGamelistFilter.cpp: back
- GuiCollectionSystemsOptions.cpp: back
- GuiMetaDataEd.cpp: back
- GuiRandomCollectionOptions.cpp: back

*es-app/src/components:*
- ScraperSearchComponent.cpp: accept
- RatingComponent.cpp: accept
- AsyncReqComponent.cpp: back

*es-app/src:*
- SystemScreenSaver.cpp: accept

**총 24개 파일, 약 60회 이상의 변경**

#### 사용자 경험

**레이아웃 전환:**
```
EmulationStation 실행
  ↓
Start 버튼
  ↓
UI SETTINGS
  ↓
BUTTON LAYOUT
  ↓
Nintendo / Sony / Xbox 선택
  ↓
즉시 적용 (ES 재시작 불필요)
```

**검증 완료 (2025-10-25):**
- ✅ Nintendo 스타일 (B=확인, A=취소) 정상 작동
- ✅ Sony/Xbox 스타일 (A=확인, B=취소) 정상 작동
- ✅ 설정 변경 후 즉시 반영
- ✅ 모든 UI 컴포넌트에서 일관된 동작
- ✅ 게임 실행/종료 정상
- ✅ 사용자 피드백: "ㅇㅋ 버튼 멀쩡하게 작동 하고.."

#### 기술적 의의

1. **유지보수성 향상**
   - 중앙 집중식 관리: `InputConfig` 한 곳에서만 수정
   - 기존 20개 이상 파일 수정 → 1개 클래스로 통합

2. **확장성**
   - 새로운 레이아웃 추가 용이
   - 기존 UI 컴포넌트 수정 불필요

3. **일관성**
   - 모든 UI에서 동일한 버튼 동작
   - 이중 swap 문제 해결

4. **사용자 친화성**
   - 메뉴에서 간편하게 전환
   - 실시간 적용

### 3. ShowFolders 기능

#### 개요

게임 폴더 표시 방식을 사용자가 제어할 수 있는 기능입니다. 멀티디스크 게임이나 단일 게임 폴더의 표시를 동적으로 조절합니다.

#### 배경

**문제점:**
- RetroPie ES에서 `ShowFolders` 옵션이 `es_settings.cfg`에는 저장되지만 실제 소스 코드에 처리 로직이 없음
- PSX 등 멀티디스크 게임을 폴더 구조로 관리하는데, 폴더 표시 방식을 제어할 수 없음
- 단일 게임만 있는 래퍼 폴더를 건너뛰고 바로 게임을 보고 싶어도 방법이 없음

#### 핵심 구현

**1) Settings 추가 (es-core/src/Settings.cpp)**

```cpp
void Settings::setDefaults()
{
    // 기존 설정들...

    // RetroPangui: ShowFolders
    mStringMap["ShowFolders"] = "always";  // 기본값: 모든 폴더 표시
}
```

**2) UI 메뉴 추가 (es-app/src/guis/GuiMenu.cpp)**

```cpp
// UI SETTINGS 메뉴 내부
auto show_folders = std::make_shared<OptionListComponent<std::string>>(
    mWindow, "SHOW FOLDERS", false);

show_folders->add("ALWAYS", "always",
                  Settings::getInstance()->getString("ShowFolders") == "always");
show_folders->add("NEVER", "never",
                  Settings::getInstance()->getString("ShowFolders") == "never");
show_folders->add("HAVING MULTIPLE GAMES", "having multiple games",
                  Settings::getInstance()->getString("ShowFolders") == "having multiple games");

s->addWithLabel("SHOW FOLDERS", show_folders);
s->addSaveFunc([show_folders, this] {
    Settings::getInstance()->setString("ShowFolders", show_folders->getSelected());
    ViewController::get()->reloadAll();  // 즉시 반영
});
```

**3) 폴더 필터링 로직 (es-app/src/FileData.cpp)**

```cpp
const std::vector<FileData*>& FileData::getChildrenListToDisplay()
{
    FileFilterIndex* idx = CollectionSystemManager::get()->getSystemToView(mSystem)->getIndex();
    std::string showFoldersSetting = Settings::getInstance()->getString("ShowFolders");

    bool needsFolderFiltering = (showFoldersSetting == "never" ||
                                  showFoldersSetting == "having multiple games");

    if (idx->isFiltered() || needsFolderFiltering)
    {
        mFilteredChildren.clear();

        for(auto child : mChildren)
        {
            // 기존 필터 체크
            if (idx->isFiltered() && !idx->showFile(child))
                continue;

            // ShowFolders 처리
            if (needsFolderFiltering && child->getType() == FOLDER)
            {
                size_t childCount = child->getChildrenByFilename().size();

                if (showFoldersSetting == "never")
                {
                    // 폴더의 모든 자식을 직접 추가
                    for(auto grandchild : child->getChildren())
                    {
                        if (!idx->isFiltered() || idx->showFile(grandchild))
                            mFilteredChildren.push_back(grandchild);
                    }
                    continue;  // 폴더 자체는 추가하지 않음
                }
                else if (showFoldersSetting == "having multiple games" && childCount == 1)
                {
                    // 단일 게임만 직접 추가
                    FileData* singleGame = child->getChildren()[0];
                    if (!idx->isFiltered() || idx->showFile(singleGame))
                        mFilteredChildren.push_back(singleGame);
                    continue;  // 폴더 자체는 추가하지 않음
                }
            }

            // 필터를 통과하거나 폴더 필터링 대상이 아닌 경우 추가
            mFilteredChildren.push_back(child);
        }

        return mFilteredChildren;
    }

    return mChildren;
}
```

#### 동작 방식

**1) always (기본값):**
```
roms/psx/
├── Final Fantasy VII/       # 폴더 표시
│   ├── disc1.bin
│   ├── disc2.bin
│   └── disc3.bin
└── Metal Gear Solid/        # 폴더 표시
    └── game.cue

게임 목록:
- Final Fantasy VII (폴더)
- Metal Gear Solid (폴더)
```

**2) never:**
```
roms/psx/
├── Final Fantasy VII/
│   ├── disc1.bin            # 직접 표시
│   ├── disc2.bin            # 직접 표시
│   └── disc3.bin            # 직접 표시
└── Metal Gear Solid/
    └── game.cue             # 직접 표시

게임 목록:
- disc1.bin
- disc2.bin
- disc3.bin
- game.cue
```

**3) having multiple games:**
```
roms/psx/
├── Final Fantasy VII/       # 폴더 표시 (3개 게임)
│   ├── disc1.bin
│   ├── disc2.bin
│   └── disc3.bin
└── Metal Gear Solid/        # 폴더 숨김, game.cue만 표시 (1개 게임)
    └── game.cue

게임 목록:
- Final Fantasy VII (폴더)
- game.cue
```

#### 사용 사례

**PSX 멀티디스크 게임:**
- `Final Fantasy VII (3 Discs)` 폴더는 표시
- `.m3u` 파일만 있는 단일 게임 폴더는 숨김
- 깔끔한 게임 목록 유지

**단일 ROM 폴더 정리:**
- `never` 설정으로 모든 래퍼 폴더 제거
- 게임만 직접 표시

#### 빌드 개선

**문제:**
- 초기 빌드 시 패치가 제대로 반영되지 않는 문제
- `make clean`만으로는 CMake 캐시가 남아있어 변경사항 미반영

**해결 (install_base_3_in_5_es.sh):**
```bash
# 변경 전
mkdir -p "$ES_BUILD_DIR/build"
cd "$ES_BUILD_DIR/build"
cmake ..
make clean
make -j$(nproc)

# 변경 후
rm -rf "$ES_BUILD_DIR/build"  # 완전히 삭제
mkdir -p "$ES_BUILD_DIR/build"
cd "$ES_BUILD_DIR/build"
cmake ..
make -j$(nproc)  # make clean 제거
```

#### 검증 완료

- ✅ 세 가지 옵션 모두 정상 작동
- ✅ 설정 변경 후 즉시 반영 (ES 재시작 불필요)
- ✅ 게임 실행 정상
- ✅ 기존 필터 기능과 호환

### 4. 다국어 지원

#### 개요

LocaleES 시스템을 통해 EmulationStation의 다국어를 지원합니다. 현재 영어와 한국어를 지원하며, 추가 언어 확장이 가능한 구조입니다.

#### 핵심 구현

**1) LocaleES 시스템 (es-core/src/LocaleES.h/cpp)**

gettext 기반의 번역 시스템:

```cpp
// LocaleES.h
#ifndef _LOCALE_ES_H_
#define _LOCALE_ES_H_

#include <string>

#define _(String) LocaleES::getText(String)

class LocaleES
{
public:
    static void init(const std::string& language);
    static std::string getText(const char* msgid);
    static void changeLanguage(const std::string& language);

private:
    static std::string currentLanguage;
};

#endif
```

**2) 한글 폰트 Fallback**

시스템에 한글 폰트를 자동으로 적용:

```bash
# install_base_3_in_5_es.sh 내부
sudo apt-get install -y fonts-noto-cjk fonts-noto-cjk-extra
```

**3) 메뉴 한글화 (GuiMenu.cpp)**

80개 이상의 메뉴 항목 번역:

```cpp
// 예시
addEntry(_("UI SETTINGS"), 0x777777FF, true, [this] { ... });
addEntry(_("SCRAPER"), 0x777777FF, true, [this] { ... });
addEntry(_("SOUND SETTINGS"), 0x777777FF, true, [this] { ... });
```

**4) CMakeLists.txt 통합**

locale 파일 컴파일 및 설치:

```cmake
# CMakeLists.txt
find_package(Gettext)
if(GETTEXT_FOUND)
    add_subdirectory(locale)
endif()
```

**5) UI 메뉴 (GuiMenu.cpp)**

```cpp
auto language = std::make_shared<OptionListComponent<std::string>>(
    mWindow, _("LANGUAGE"), false);

language->add("English", "en",
              Settings::getInstance()->getString("Language") == "en");
language->add("한국어", "ko",
              Settings::getInstance()->getString("Language") == "ko");

s->addWithLabel(_("LANGUAGE"), language);
s->addSaveFunc([language, this] {
    Settings::getInstance()->setString("Language", language->getSelected());
    LocaleES::changeLanguage(language->getSelected());
    // ES 재시작 안내 메시지
    mWindow->pushGui(new GuiMsgBox(mWindow,
        _("Language changed. Please restart EmulationStation.")));
});
```

#### 언어 파일 구조

```
locale/
├── en/
│   └── LC_MESSAGES/
│       ├── emulationstation.po
│       └── emulationstation.mo
└── ko/
    └── LC_MESSAGES/
        ├── emulationstation.po
        └── emulationstation.mo
```

#### 검증 완료

- ✅ 영어 ↔ 한국어 전환 정상
- ✅ 80개 이상 메뉴 항목 번역
- ✅ 한글 폰트 정상 표시
- ✅ 메뉴에서 언어 전환 가능

---

## 시스템 모듈

RetroPangui의 핵심 기능은 `scriptmodules/` 디렉토리의 여러 모듈로 구성되어 있습니다.

### config.sh - 전역 환경 변수 설정

#### 역할

프로젝트의 모든 환경 변수, 경로, 설정을 정의하는 유일한 파일입니다. 모든 스크립트는 이 파일을 source하여 환경 설정을 로드합니다.

#### 주요 내용

**1) 기본 경로 설정**

```bash
# 프로젝트 루트 디렉토리 자동 감지
export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export MODULES_DIR="$ROOT_DIR/scriptmodules"
export RESOURCES_DIR="$ROOT_DIR/resources"
```

**2) 사용자 정보**

```bash
# sudo를 사용해도 실제 사용자 계정 찾기
export __user="$(get_effective_user)"
export USER_HOME="$(eval echo ~$__user)"
```

**3) 버전 및 핵심 경로**

```bash
export __version="0.9.2"
export INSTALL_ROOT_DIR="/opt/retropangui"
export TEMP_DIR_BASE="/tmp/retropangui"
export LOG_DIR="$ROOT_DIR/log"
export RETROARCH_BIN_PATH="$INSTALL_ROOT_DIR/bin/retroarch"
export LIBRETRO_CORE_PATH="$INSTALL_ROOT_DIR/libretrocores"
```

**4) 사용자별 경로**

```bash
export USER_SHARE_PATH="$USER_HOME/share"
export USER_ROMS_PATH="$USER_SHARE_PATH/roms"
export USER_BIOS_PATH="$USER_SHARE_PATH/bios"
export USER_SAVES_PATH="$USER_SHARE_PATH/saves"
export USER_SCREENS_PATH="$USER_SHARE_PATH/screenshots"
export USER_MUSIC_PATH="$USER_SHARE_PATH/music"
export USER_THEMES_PATH="$USER_SHARE_PATH/themes"
export USER_OVERLAYS_PATH="$USER_SHARE_PATH/overlays"
export USER_CHEATS_PATH="$USER_SHARE_PATH/cheats"

export USER_SYSTEM_PATH="$USER_SHARE_PATH/system"
export USER_CONFIG_PATH="$USER_SYSTEM_PATH/configs"
export USER_LOGS_PATH="$USER_SYSTEM_PATH/logs"
export CORE_CONFIG_PATH="$USER_CONFIG_PATH/cores"
export RA_CONFIG_PATH="$USER_CONFIG_PATH/retroarch"

export RA_CONFIG_DIR="$USER_HOME/.config/retroarch"
export ES_CONFIG_DIR="$USER_HOME/.emulationstation"
```

**5) Git 저장소 URL**

```bash
export RECALBOX_GIT_URL="https://gitlab.com/recalbox/recalbox.git"
export RETROPIE_SETUP_GIT_URL="https://github.com/RetroPie/RetroPie-Setup.git"
export RA_GIT_URL="https://github.com/libretro/RetroArch.git"
export ES_GIT_URL="https://github.com/LeonardWard/retropangui-emulationstation.git"
export SYSTEMLIST_CSV_PATH="$MODULES_DIR/systemlist.csv"
```

**6) 빌드 의존성 패키지**

```bash
export BUILD_DEPS=(
    build-essential cmake pkg-config samba
    # RetroArch/Libretro
    libssl-dev libx11-dev libgl1-mesa-dev libegl1-mesa-dev libsdl2-dev
    libasound2-dev libudev-dev libxkbcommon-dev libgbm-dev
    libavcodec-dev libavformat-dev libavutil-dev libswscale-dev
    # EmulationStation
    libboost-all-dev libfreeimage-dev libcurl4-openssl-dev
    libxml2-dev libfontconfig1-dev libsdl2-image-dev libsdl2-ttf-dev
    libexpat1-dev libvlc-dev rapidjson-dev libpugixml-dev
    # 기타
    gamemode
)
```

**7) 플랫폼 탐지**

```bash
__platform_arch=$(uname -m)
export __platform="$__platform_arch"

case "$__platform_arch" in
    x86_64)
        __platform_flags+=("x86_64" "64bit" "x86")
        ;;
    aarch64)
        __platform_flags+=("aarch64" "64bit" "arm")
        ;;
    armv7l)
        __platform_flags+=("armv7l" "32bit" "arm" "armv7")
        ;;
esac

export __platform_flags
```

### func.sh - 공통 기능 함수

#### 역할

프로젝트 전반에서 사용되는 공통 함수들을 정의합니다.

#### 주요 함수

**1) 사용자 정보 함수**

```bash
# 실제 사용자 계정 찾기 (sudo 사용 시에도)
get_effective_user() {
    if [[ -n "$SUDO_USER" ]]; then
        echo "$SUDO_USER"
    else
        echo "$USER"
    fi
}
```

**2) Git 관련 함수**

```bash
# Git 저장소 클론 또는 풀
git_Pull_Or_Clone() {
    local url="$1"
    local dest="$2"
    shift 2
    local extra_args=("$@")

    if [[ -d "$dest/.git" ]]; then
        log_msg INFO "Git pull: $dest"
        git -C "$dest" pull
    else
        log_msg INFO "Git clone: $url → $dest"
        git clone "${extra_args[@]}" "$url" "$dest"
    fi
}

# Git 프로젝트 디렉토리 이름 추출
get_Git_Project_Dir_Name() {
    local url="$1"
    basename "$url" .git
}
```

**3) 명령어 존재 확인**

```bash
command_exists() {
    command -v "$1" &> /dev/null
}
```

**4) 모듈 설치 확인**

```bash
is_module_installed() {
    local module_id="$1"
    local module_type="$2"

    case "$module_type" in
        libretrocores)
            [[ -f "$LIBRETRO_CORE_PATH/${module_id}_libretro.so" ]]
            ;;
        emulators)
            [[ -d "$INSTALL_ROOT_DIR/emulators/$module_id" ]]
            ;;
        *)
            return 1
            ;;
    esac
}
```

**5) 패키지 스캔 함수**

```bash
get_all_packages() {
    local desc_max_width="${1:-40}"
    local script_root="$MODULES_DIR/retropie_setup/scriptmodules"

    find "$script_root" -maxdepth 2 -type f -name "*.sh" | while read -r script_path; do
        local module_type=$(basename "$(dirname "$script_path")")

        # scriptmodules 자체는 스킵
        [[ "$module_type" == "scriptmodules" ]] && continue

        # 메타데이터 추출
        local rp_module_id=""
        local rp_module_desc=""
        local rp_module_section=""
        local rp_module_flags=""

        while IFS= read -r line; do
            line="${line%%#*}"  # 주석 제거

            if [[ -z "$rp_module_id" && "$line" =~ rp_module_id[[:space:]]*= ]]; then
                rp_module_id=$(echo "$line" | sed -E 's/.*rp_module_id[[:space:]]*=[[:space:]]*//; s/^["'\'']*//; s/["'\'']*[[:space:]]*$//')
            elif [[ -z "$rp_module_desc" && "$line" =~ rp_module_desc[[:space:]]*= ]]; then
                rp_module_desc=$(echo "$line" | sed -E 's/.*rp_module_desc[[:space:]]*=[[:space:]]*//; s/^["'\'']*//; s/["'\'']*[[:space:]]*$//')
            elif [[ -z "$rp_module_section" && "$line" =~ rp_module_section[[:space:]]*= ]]; then
                rp_module_section=$(echo "$line" | sed -E 's/.*rp_module_section[[:space:]]*=[[:space:]]*//; s/^["'\'']*//; s/["'\'']*[[:space:]]*$//')
            elif [[ -z "$rp_module_flags" && "$line" =~ rp_module_flags[[:space:]]*= ]]; then
                rp_module_flags=$(echo "$line" | sed -E 's/.*rp_module_flags[[:space:]]*=[[:space:]]*//; s/^["'\''(]*//; s/["'\'')]*[[:space:]]*$//')
            fi
        done < "$script_path"

        [[ -z "$rp_module_id" ]] && continue

        # 플랫폼 체크
        if ! rp_checkModulePlatform "$rp_module_flags"; then
            continue
        fi

        # 섹션 결정
        local section="$rp_module_section"
        local final_section=$(echo "$section" | awk '{print $1}')

        for part in $section; do
            if [[ "$part" == *"="* ]]; then
                local platform_req=$(echo "$part" | cut -d'=' -f1)
                local new_section=$(echo "$part" | cut -d'=' -f2)
                for p_flag in "${__platform_flags[@]}"; do
                    if [[ "$platform_req" == "$p_flag" ]]; then
                        final_section="$new_section"
                        break 2
                    fi
                done
            fi
        done

        # 설치 여부 확인
        local status="OFF"
        if is_module_installed "$rp_module_id" "$module_type"; then
            status="ON"
        fi

        # 설명 자르기
        local truncated_desc="$rp_module_desc"
        if [[ ${#truncated_desc} -gt "$desc_max_width" ]]; then
            truncated_desc="${truncated_desc:0:$((desc_max_width - 3))}..."
        fi

        # null 구분자로 출력
        printf "%s\0%s\0%s\0%s\0%s\0" "$rp_module_id" "$truncated_desc" "$final_section" "$module_type" "$status"
    done
}
```

**6) es_systems.xml 생성 함수**

```bash
generate_es_systems_xml_multi_core() {
    local src_csv="$1"
    local dest_xml="$2"

    echo '<?xml version="1.0"?>' | sudo tee "$dest_xml" > /dev/null
    echo "<systemList>" | sudo tee -a "$dest_xml" > /dev/null

    # systemlist.csv 파싱
    # (실제 구현은 더 복잡함)

    echo "</systemList>" | sudo tee -a "$dest_xml" > /dev/null
}
```

### helpers.sh - 로그 및 보조 함수

#### 역할

로그 기능과 기타 보조 함수들을 제공합니다.

#### 주요 함수

**1) 로그 디렉토리 생성**

```bash
ensure_log_dir() {
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
        chmod 755 "$LOG_DIR"
    fi
}
```

**2) 로그 메시지 출력**

```bash
log_msg() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    case "$level" in
        ERROR)
            echo "[$timestamp] [ERROR] $message" | tee -a "$LOG_FILE" >&2
            ;;
        WARN)
            echo "[$timestamp] [WARN] $message" | tee -a "$LOG_FILE"
            ;;
        INFO)
            echo "[$timestamp] [INFO] $message" | tee -a "$LOG_FILE"
            ;;
        SUCCESS)
            echo "[$timestamp] [SUCCESS] $message" | tee -a "$LOG_FILE"
            ;;
        STEP)
            echo "[$timestamp] [STEP] ========== $message ==========" | tee -a "$LOG_FILE"
            ;;
        DEBUG)
            echo "[$timestamp] [DEBUG] $message" | tee -a "$LOG_FILE"
            ;;
        *)
            echo "[$timestamp] $message" | tee -a "$LOG_FILE"
            ;;
    esac
}
```

### ui.sh - WhipTail TUI

#### 역할

WhipTail 기반의 텍스트 사용자 인터페이스를 제공합니다.

#### 주요 함수

**1) 초기화 함수**

```bash
install_core_dependencies() {
    local CORE_DEPS=("whiptail" "dialog" "git" "wget" "curl" "unzip")
    local MISSING_DEPS=()

    for dep in "${CORE_DEPS[@]}"; do
        if ! command_exists "$dep"; then
            MISSING_DEPS+=("$dep")
        fi
    done

    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        log_msg WARN "다음 필수 유틸리티가 누락: ${MISSING_DEPS[*]}"
        sudo apt-get update && sudo apt-get upgrade -y
        sudo apt-get install -y "${MISSING_DEPS[@]}"
    fi

    # RetroPie 스크립트 모듈 다운로드
    local RETROPIE_SETUP_DIR="$MODULES_DIR/retropie_setup"
    local EXT_FOLDER="$(get_Git_Project_Dir_Name "$RETROPIE_SETUP_GIT_URL")"

    git_Pull_Or_Clone "$RETROPIE_SETUP_GIT_URL" "$TEMP_DIR_BASE/$EXT_FOLDER" --depth=1

    mkdir -p "$RETROPIE_SETUP_DIR"
    rsync -avzr "$TEMP_DIR_BASE/$EXT_FOLDER/scriptmodules" "$RETROPIE_SETUP_DIR"
    rsync -avzr "$TEMP_DIR_BASE/$EXT_FOLDER/retropie_packages.sh" "$RETROPIE_SETUP_DIR"
    rsync -avzr "$TEMP_DIR_BASE/$EXT_FOLDER/retropie_setup.sh" "$RETROPIE_SETUP_DIR"
}
```

**2) Base System 설치**

```bash
run_base_system_install() {
    if (whiptail --title "Base System 설치" \
        --yesno "RetroArch/EmulationStation 설치를 진행하시겠습니까?" 12 60); then

        log_msg INFO "Base System 설치 시작..."
        source "$MODULES_DIR/system_install.sh"
        local INSTALL_STATUS=$?

        if [ $INSTALL_STATUS -eq 0 ]; then
            whiptail --title "✅ 설치 성공" \
                --msgbox "Base System 설치가 완료되었습니다." 10 60
        else
            whiptail --title "❌ 설치 실패" \
                --msgbox "설치 중 오류 발생. 로그 확인: $LOG_FILE" 10 60
        fi
    fi
}
```

**3) 패키지 관리 메뉴**

```bash
manage_packages_by_section() {
    local section_title="$1"
    local section_id="$2"

    # 터미널 크기 동적 감지
    local term_height=$(tput lines 2>/dev/null || echo 24)
    local term_width=$(tput cols 2>/dev/null || echo 80)

    local options=()
    declare -A module_info

    # get_all_packages 함수로 패키지 스캔
    while IFS= read -r -d '' id && IFS= read -r -d '' desc && \
          IFS= read -r -d '' section && IFS= read -r -d '' type && \
          IFS= read -r -d '' status; do
        if [[ "$section" == "$section_id" ]]; then
            options+=("$id" "$desc" "$status")
            module_info["$id,type"]="$type"
            module_info["$id,status"]="$status"
        fi
    done < <(get_all_packages)

    if [ ${#options[@]} -eq 0 ]; then
        whiptail --title "정보" \
            --msgbox "이 섹션에는 설치 가능한 패키지가 없습니다." 8 70
        return
    fi

    # WhipTail checklist 표시
    local CHOICES
    CHOICES=$(whiptail --title "$section_title" \
        --checklist "설치할 패키지를 스페이스바로 선택하세요." \
        "$box_height" "$box_width" "$list_height" "${options[@]}" 3>&1 1>&2 2>&3)

    if [ $? -eq 0 ]; then
        for CHOICE in $CHOICES; do
            local module_id=$(echo "$CHOICE" | tr -d '"')
            local module_type=${module_info["$module_id,type"]}

            echo "INSTALLING: $module_id ($module_type)"
            install_module "$module_id" "$module_type"
        done

        read -p "완료. [Enter]를 누르세요."
    fi
}
```

**4) 메인 UI**

```bash
main_ui() {
    install_core_dependencies

    while true; do
        CHOICE=$(whiptail --title "Retro Pangui Configuration Manager (v$__version)" \
            --menu "메뉴를 선택하세요." $HEIGHT $WIDTH $CHOICE_HEIGHT \
            "1" "Base System 설치" \
            "2" "Base System 업데이트" \
            "3" "패키지 관리 (Core/Main/Driver)" \
            "4" "설정 / 기타 도구" \
            "5" "스크립트 업데이트" \
            "6" "전부 설치 제거 (Share 폴더 제외)" \
            "7" "시스템 재부팅" \
            "8" "종료" 3>&1 1>&2 2>&3)

        case $CHOICE in
            1) run_base_system_install ;;
            2) run_base_system_update ;;
            3) package_management_menu ;;
            4) config_tools_menu ;;
            5) update_script ;;
            6) uninstall_all ;;
            7) reboot_system ;;
            8) break ;;
        esac
    done
}
```

### packages.sh - 패키지 설치 함수

#### 역할

개별 모듈(코어, 에뮬레이터, Ports)을 소스에서 빌드하고 설치하는 범용 함수를 제공합니다.

#### install_module 함수

```bash
install_module() {
    local module_id="$1"
    local module_type="$2"

    if [[ -z "$module_id" || -z "$module_type" ]]; then
        log_msg ERROR "Module ID 또는 Type이 제공되지 않음"
        return 1
    fi

    source "$MODULES_DIR/ext_retropie_core.sh"
    setup_env

    export md_id="$module_id"
    export md_build="$INSTALL_BUILD_DIR/$module_id"

    case "$module_type" in
        libretrocores)
            export md_inst="$LIBRETRO_CORE_PATH/$module_id"
            ;;
        emulators|ports)
            export md_inst="$INSTALL_ROOT_DIR/$module_type/$module_id"
            ;;
        *)
            log_msg ERROR "알 수 없는 모듈 타입: $module_type"
            return 1
            ;;
    esac

    log_msg STEP "$module_id ($module_type) 모듈 설치 시작..."

    local script_path="$MODULES_DIR/retropie_setup/scriptmodules/$module_type/$module_id.sh"
    if [[ ! -f "$script_path" ]]; then
        log_msg ERROR "모듈 스크립트 파일을 찾을 수 없음: $script_path"
        return 1
    fi

    export md_ret_files=()
    source "$script_path"

    # 5단계 실행: depends → sources → build → install → configure
    local funcs=("depends" "sources" "build" "install" "configure")
    for func_name in "${funcs[@]}"; do
        log_msg INFO "[$module_id] '$func_name' 단계 실행..."
        local status=0

        case "$func_name" in
            depends)
                # depends는 무조건 성공 처리
                if declare -f "${func_name}_$module_id" > /dev/null; then
                    "${func_name}_$module_id" || true
                fi
                ;;
            sources)
                if [[ -d "$md_build" ]]; then
                    log_msg INFO "[$module_id] 빌드 디렉토리 정리: $md_build"
                    sudo rm -rf "$md_build" || { log_msg ERROR "빌드 디렉토리 정리 실패"; status=1; }
                fi
                if [[ $status -eq 0 ]]; then
                    if declare -f "sources_$module_id" > /dev/null; then
                        sources_"$module_id" || status=$?
                    elif [[ -n "$rp_module_repo" ]]; then
                        git_Pull_Or_Clone "$rp_module_repo" "$md_build" || status=$?
                    else
                        log_msg WARN "[$module_id] 'sources' 함수 또는 'rp_module_repo'가 정의되지 않음"
                    fi
                fi
                ;;
            build|install)
                if [[ -d "$md_build" ]]; then
                    pushd "$md_build" >/dev/null || { log_msg ERROR "디렉토리 이동 실패: $md_build"; status=1; }
                    if [[ $status -eq 0 ]]; then
                        "${func_name}_$module_id" || status=$?
                        popd >/dev/null
                    fi
                else
                    log_msg ERROR "[$module_id] 소스 디렉토리를 찾을 수 없음: $md_build"
                    status=1
                fi
                ;;
            *)
                if declare -f "${func_name}_$module_id" > /dev/null; then
                    "${func_name}_$module_id" || status=$?
                fi
                ;;
        esac

        if [[ $status -ne 0 ]]; then
            log_msg ERROR "[$module_id] '$func_name' 단계 실행 중 오류 (Exit Code: $status)"
            return 1
        fi
    done

    # libretrocores의 경우 최종 코어 파일 복사
    if [[ "$module_type" == "libretrocores" ]]; then
        log_msg INFO "[$module_id] 최종 코어 파일 복사..."
        if [[ ${#md_ret_files[@]} -eq 0 ]]; then
            log_msg ERROR "[$module_id] 'md_ret_files'가 설정되지 않음"
            return 1
        fi
        installLibretroCore "$md_build" "$module_id" "$md_inst" || return 1
    fi

    log_msg SUCCESS "[$module_id] 설치 완료"
    return 0
}
```

### ext_retropie_*.sh - RetroPie 호환 함수

#### 개요

RetroPie-Setup의 핵심 함수들을 RetroPangui 환경에 맞게 재구현한 파일들입니다.

#### ext_retropie_core.sh

RetroPie의 핵심 함수들:

```bash
# 환경 설정
setup_env() {
    # RetroPie 환경 변수 설정
    export __nodialog=1
    export __platform
    export __platform_flags
}

# 플랫폼 체크
rp_checkModulePlatform() {
    local flags="$1"
    [[ -z "$flags" ]] && return 0

    for flag in $flags; do
        for p_flag in "${__platform_flags[@]}"; do
            [[ "$flag" == "$p_flag" ]] && return 0
        done
    done
    return 1
}

# 코어 설치
installLibretroCore() {
    local src_dir="$1"
    local core_name="$2"
    local dest_dir="$3"

    mkdir -p "$dest_dir"

    for file in "${md_ret_files[@]}"; do
        if [[ -f "$src_dir/$file" ]]; then
            sudo cp "$src_dir/$file" "$dest_dir/"
            log_msg SUCCESS "코어 파일 복사: $file → $dest_dir/"
        else
            log_msg ERROR "코어 파일을 찾을 수 없음: $src_dir/$file"
            return 1
        fi
    done

    return 0
}
```

#### ext_retropie_func.sh

RetroPie의 보조 함수들:

```bash
# 디렉토리 권한 설정
chown_$(get_effective_user)() {
    local path="$1"
    sudo chown -R "$__user:$__user" "$path"
}

# ROM 디렉토리 생성
mkRomDir() {
    local system="$1"
    local dir="$USER_ROMS_PATH/$system"
    mkdir -p "$dir"
    chown_$(get_effective_user) "$dir"
}

# 에뮬레이터 등록
addEmulator() {
    local default="$1"
    local id="$2"
    local system="$3"
    local so_path="$4"

    log_msg INFO "에뮬레이터 등록: $id for $system ($so_path)"
    # 실제 구현은 emulators.cfg 파일에 기록
}
```

---

## EmulationStation 커스터마이징

(이전에 작성한 내용 포함, 여기서는 요약)

### 논리 버튼 매핑 시스템

- InputConfig 클래스 확장
- Nintendo/Sony/Xbox 레이아웃
- 24개 UI 컴포넌트 리팩토링
- 실시간 전환 지원

### ShowFolders 기능

- always/never/having multiple games
- 멀티디스크 게임 관리
- 동적 필터링 로직

### 다국어 지원

- LocaleES 시스템
- 영어/한국어
- 80개 이상 메뉴 번역

---

## 멀티코어 시스템

(이전에 작성한 내용 포함, 여기서는 요약)

### CoreInfo 구조체

```cpp
struct CoreInfo {
    std::string name;
    int priority;
    std::vector<std::string> extensions;
};
```

### es_systems.xml 형식

```xml
<cores>
  <core name="pcsx_rearmed" priority="2" extensions=".bin .cue"/>
  <core name="beetle_psx" priority="3" extensions=".chd"/>
</cores>
```

### 동적 명령 생성

Settings API 기반 경로 관리로 RetroArch 명령 동적 조립

---

## 5단계 자동 설치

### 1단계: 의존성 설치

#### 스크립트: install_base_1_in_5_deps.sh

```bash
#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$MODULES_DIR/helpers.sh"

install_dependencies() {
    log_msg STEP "1단계: 의존성 패키지 설치 시작"

    log_msg INFO "패키지 목록 업데이트 중..."
    sudo apt-get update || { log_msg ERROR "apt-get update 실패"; return 1; }

    log_msg INFO "시스템 업그레이드 중..."
    sudo apt-get upgrade -y || { log_msg WARN "apt-get upgrade 실패 (계속 진행)"; }

    log_msg INFO "빌드 의존성 패키지 설치 중..."
    for pkg in "${BUILD_DEPS[@]}"; do
        if dpkg -s "$pkg" &> /dev/null; then
            log_msg INFO "이미 설치됨: $pkg"
        else
            log_msg INFO "설치 중: $pkg"
            sudo apt-get install -y "$pkg" || {
                log_msg ERROR "패키지 설치 실패: $pkg"
                return 1
            }
        fi
    done

    log_msg SUCCESS "1단계: 의존성 패키지 설치 완료"
    return 0
}

install_dependencies
```

#### 설치되는 패키지

**빌드 도구:**
- build-essential: gcc, g++, make 등
- cmake: CMake 빌드 시스템
- pkg-config: 패키지 설정 관리
- git: 소스 코드 다운로드

**RetroArch/Libretro 의존성:**
- libssl-dev: SSL/TLS 지원
- libx11-dev: X11 윈도우 시스템
- libgl1-mesa-dev, libegl1-mesa-dev: OpenGL 지원
- libsdl2-dev: SDL2 라이브러리
- libasound2-dev: ALSA 오디오
- libudev-dev: udev 장치 관리
- libxkbcommon-dev: 키보드 입력
- libgbm-dev: Generic Buffer Management
- libavcodec-dev, libavformat-dev, libavutil-dev, libswscale-dev: FFmpeg 라이브러리

**EmulationStation 의존성:**
- libboost-all-dev: Boost C++ 라이브러리
- libfreeimage-dev: 이미지 처리
- libcurl4-openssl-dev: HTTP 클라이언트
- libxml2-dev: XML 파싱
- libfontconfig1-dev: 폰트 설정
- libsdl2-image-dev, libsdl2-ttf-dev: SDL2 확장
- libexpat1-dev: XML 파서
- libvlc-dev: VLC 미디어 플레이어
- rapidjson-dev: JSON 파서
- libpugixml-dev: XML 파서

**기타:**
- gamemode: 게임 모드 최적화
- samba: 네트워크 공유

### 2단계: RetroArch 설치

#### 스크립트: install_base_2_in_5_ra.sh

```bash
#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$MODULES_DIR/helpers.sh"

install_retroarch() {
    log_msg STEP "2단계: RetroArch 설치 시작"

    local RA_BUILD_DIR="$INSTALL_BUILD_DIR/RetroArch"

    # Git clone 또는 pull
    log_msg INFO "RetroArch 소스 다운로드..."
    git_Pull_Or_Clone "$RA_GIT_URL" "$RA_BUILD_DIR"

    cd "$RA_BUILD_DIR" || { log_msg ERROR "디렉토리 이동 실패"; return 1; }

    # Configure
    log_msg INFO "RetroArch configure 실행..."
    ./configure --prefix="$INSTALL_ROOT_DIR" \
                --enable-dbus \
                --enable-sdl2 \
                --enable-opengl \
                --enable-ffmpeg || {
        log_msg ERROR "configure 실패"
        return 1
    }

    # Build
    log_msg INFO "RetroArch 빌드 중... ($(nproc)개 코어 사용)"
    make -j$(nproc) || { log_msg ERROR "빌드 실패"; return 1; }

    # Install
    log_msg INFO "RetroArch 설치 중..."
    sudo make install || { log_msg ERROR "설치 실패"; return 1; }

    # Assets 설치
    install_ra_assets

    # Joypad Autoconfig 설치
    install_ra_joypad_autoconfig

    # Core Info 설치
    install_ra_core_info

    # Database 설치
    install_ra_database

    # Overlays 설치
    install_ra_overlays

    # Shaders 설치
    install_ra_shaders

    # 초기 설정 파일 복사
    log_msg INFO "RetroArch 초기 설정 파일 복사..."
    mkdir -p "$RA_CONFIG_DIR"
    if [[ -f "$MODULES_DIR/retroarch.init.cfg" ]]; then
        cp "$MODULES_DIR/retroarch.init.cfg" "$RA_CONFIG_DIR/retroarch.cfg"
        chown_$(get_effective_user) "$RA_CONFIG_DIR/retroarch.cfg"
    fi

    log_msg SUCCESS "2단계: RetroArch 설치 완료"
    return 0
}

install_ra_assets() {
    log_msg INFO "RetroArch Assets 설치 중..."
    local ASSETS_DIR="$INSTALL_BUILD_DIR/retroarch-assets"

    git_Pull_Or_Clone "$RA_ASSETS_GIT_URL" "$ASSETS_DIR"
    sudo mkdir -p "$INSTALL_ROOT_DIR/share/retroarch/assets"
    sudo cp -r "$ASSETS_DIR"/* "$INSTALL_ROOT_DIR/share/retroarch/assets/"

    log_msg SUCCESS "Assets 설치 완료"
}

install_ra_joypad_autoconfig() {
    log_msg INFO "Joypad Autoconfig 설치 중..."
    local AUTOCONFIG_DIR="$INSTALL_BUILD_DIR/retroarch-joypad-autoconfig"

    git_Pull_Or_Clone "$RA_JOYPAD_AUTOCONFIG_GIT_URL" "$AUTOCONFIG_DIR"
    sudo mkdir -p "$INSTALL_ROOT_DIR/share/retroarch/autoconfig"
    sudo cp -r "$AUTOCONFIG_DIR"/* "$INSTALL_ROOT_DIR/share/retroarch/autoconfig/"

    log_msg SUCCESS "Joypad Autoconfig 설치 완료"
}

install_ra_core_info() {
    log_msg INFO "Core Info 설치 중..."
    local CORE_INFO_DIR="$INSTALL_BUILD_DIR/libretro-core-info"

    git_Pull_Or_Clone "$RA_CORE_INFO_GIT_URL" "$CORE_INFO_DIR"
    sudo mkdir -p "$INSTALL_ROOT_DIR/share/retroarch/info"
    sudo cp "$CORE_INFO_DIR"/*.info "$INSTALL_ROOT_DIR/share/retroarch/info/"

    log_msg SUCCESS "Core Info 설치 완료"
}

install_ra_database() {
    log_msg INFO "Database 설치 중..."
    local DATABASE_DIR="$INSTALL_BUILD_DIR/libretro-database"

    git_Pull_Or_Clone "$RA_DATABASE_GIT_URL" "$DATABASE_DIR"
    sudo mkdir -p "$INSTALL_ROOT_DIR/share/retroarch/database"
    sudo cp -r "$DATABASE_DIR/rdb"/* "$INSTALL_ROOT_DIR/share/retroarch/database/"

    log_msg SUCCESS "Database 설치 완료"
}

install_ra_overlays() {
    log_msg INFO "Overlays 설치 중..."
    local OVERLAYS_DIR="$INSTALL_BUILD_DIR/common-overlays"

    git_Pull_Or_Clone "$RA_OVERLAYS_GIT_URL" "$OVERLAYS_DIR"
    sudo mkdir -p "$INSTALL_ROOT_DIR/share/retroarch/overlays"
    sudo cp -r "$OVERLAYS_DIR"/* "$INSTALL_ROOT_DIR/share/retroarch/overlays/"

    log_msg SUCCESS "Overlays 설치 완료"
}

install_ra_shaders() {
    log_msg INFO "Shaders 설치 중..."
    local SHADERS_DIR="$INSTALL_BUILD_DIR/glsl-shaders"

    git_Pull_Or_Clone "$RA_SHADERS_GIT_URL" "$SHADERS_DIR"
    sudo mkdir -p "$INSTALL_ROOT_DIR/share/retroarch/shaders"
    sudo cp -r "$SHADERS_DIR"/* "$INSTALL_ROOT_DIR/share/retroarch/shaders/"

    log_msg SUCCESS "Shaders 설치 완료"
}

install_retroarch
```

### 3단계: EmulationStation 설치

#### 스크립트: install_base_3_in_5_es.sh

```bash
#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$MODULES_DIR/helpers.sh"
source "$MODULES_DIR/es_systems_generator.sh"

install_emulationstation() {
    log_msg STEP "3단계: EmulationStation 설치 시작"

    local ES_BUILD_DIR="$INSTALL_BUILD_DIR/EmulationStation"

    # Git clone (RetroPangui 포크)
    log_msg INFO "EmulationStation 소스 다운로드..."
    git_Pull_Or_Clone "$ES_GIT_URL" "$ES_BUILD_DIR"

    cd "$ES_BUILD_DIR" || { log_msg ERROR "디렉토리 이동 실패"; return 1; }

    # 빌드 디렉토리 완전히 재생성
    log_msg INFO "빌드 디렉토리 재생성..."
    rm -rf "$ES_BUILD_DIR/build"
    mkdir -p "$ES_BUILD_DIR/build"
    cd "$ES_BUILD_DIR/build" || { log_msg ERROR "build 디렉토리 이동 실패"; return 1; }

    # CMake
    log_msg INFO "CMake 실행..."
    cmake .. || { log_msg ERROR "CMake 실패"; return 1; }

    # Build
    log_msg INFO "EmulationStation 빌드 중... ($(nproc)개 코어 사용)"
    make -j$(nproc) || { log_msg ERROR "빌드 실패"; return 1; }

    # Install
    log_msg INFO "EmulationStation 설치 중..."
    sudo make install || { log_msg ERROR "설치 실패"; return 1; }

    # es_systems.xml 생성
    log_msg INFO "es_systems.xml 생성 중..."
    local ES_SYSTEMS_PATH="$ES_CONFIG_DIR/es_systems.xml"
    mkdir -p "$ES_CONFIG_DIR"
    generate_es_systems_xml_multi_core "$SYSTEMLIST_CSV_PATH" "$ES_SYSTEMS_PATH"
    chown_$(get_effective_user) "$ES_CONFIG_DIR"
    chown_$(get_effective_user) "$ES_SYSTEMS_PATH"

    # locale 파일 설치
    log_msg INFO "Locale 파일 설치 중..."
    if [[ -d "$ES_BUILD_DIR/locale" ]]; then
        sudo cp -r "$ES_BUILD_DIR/locale" "$INSTALL_ROOT_DIR/share/"
    fi

    log_msg SUCCESS "3단계: EmulationStation 설치 완료"
    return 0
}

install_emulationstation
```

### 4단계: 코어 설치

#### 스크립트: install_base_4_in_5_cores.sh

```bash
#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$MODULES_DIR/helpers.sh"
source "$MODULES_DIR/packages.sh"

install_cores() {
    log_msg STEP "4단계: Libretro 코어 설치 시작"

    # BASE 코어 목록 (systemlist.csv에서 추출 가능)
    local CORE_LIST=(
        "snes9x"
        "mgba"
        "pcsx_rearmed"
        "mupen64plus_next"
        "nestopia"
        "fceumm"
        "genesisplusgx"
        "gambatte"
    )

    local total=${#CORE_LIST[@]}
    local current=0

    for core in "${CORE_LIST[@]}"; do
        current=$((current + 1))
        log_msg INFO "[$current/$total] 코어 설치: $core"

        install_module "$core" "libretrocores" || {
            log_msg WARN "코어 설치 실패: $core (계속 진행)"
        }
    done

    log_msg SUCCESS "4단계: Libretro 코어 설치 완료"
    return 0
}

install_cores
```

### 5단계: 환경 설정

#### 스크립트: install_base_5_in_5_setup_env.sh

```bash
#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$MODULES_DIR/helpers.sh"

setup_environment() {
    log_msg STEP "5단계: 환경 설정 시작"

    # 사용자 디렉토리 생성
    log_msg INFO "사용자 디렉토리 생성 중..."
    mkdir -p "$USER_SHARE_PATH"
    mkdir -p "$USER_ROMS_PATH"
    mkdir -p "$USER_BIOS_PATH"
    mkdir -p "$USER_SAVES_PATH"
    mkdir -p "$USER_SCREENS_PATH"
    mkdir -p "$USER_MUSIC_PATH"
    mkdir -p "$USER_THEMES_PATH"
    mkdir -p "$USER_OVERLAYS_PATH"
    mkdir -p "$USER_CHEATS_PATH"
    mkdir -p "$USER_SYSTEM_PATH"
    mkdir -p "$USER_CONFIG_PATH"
    mkdir -p "$USER_LOGS_PATH"
    mkdir -p "$USER_SCRIPTS_PATH"
    mkdir -p "$CORE_CONFIG_PATH"
    mkdir -p "$RA_CONFIG_PATH"

    # 시스템별 ROM 디렉토리 생성 (주요 시스템만)
    local SYSTEMS=("nes" "snes" "psx" "gba" "n64" "dreamcast" "arcade")
    for sys in "${SYSTEMS[@]}"; do
        mkdir -p "$USER_ROMS_PATH/$sys"
    done

    # 시스템별 코어 설정 디렉토리 생성
    for sys in "${SYSTEMS[@]}"; do
        mkdir -p "$CORE_CONFIG_PATH/$sys"
        # 기본 retroarch.cfg 복사
        if [[ ! -f "$CORE_CONFIG_PATH/$sys/retroarch.cfg" ]]; then
            cp "$RA_CONFIG_DIR/retroarch.cfg" "$CORE_CONFIG_PATH/$sys/retroarch.cfg" 2>/dev/null || true
        fi
    done

    # 권한 및 소유권 설정
    log_msg INFO "권한 및 소유권 설정 중..."
    chown_$(get_effective_user) "$USER_SHARE_PATH"
    chown_$(get_effective_user) "$USER_HOME/.emulationstation"
    chown_$(get_effective_user) "$USER_HOME/.config/retroarch"

    # README 파일 생성
    cat > "$USER_ROMS_PATH/README.txt" << 'EOF'
RetroPangui ROM 디렉토리

이 디렉토리에 게임 ROM 파일을 시스템별로 정리하세요.

예시:
- nes/: 패미컴/NES ROM (.nes)
- snes/: 슈퍼패미컴/SNES ROM (.sfc, .smc)
- psx/: 플레이스테이션 ROM (.bin, .cue, .chd)
- gba/: 게임보이 어드밴스 ROM (.gba)

BIOS 파일은 ~/share/bios/ 디렉토리에 넣으세요.
EOF

    chown_$(get_effective_user) "$USER_ROMS_PATH/README.txt"

    log_msg SUCCESS "5단계: 환경 설정 완료"
    return 0
}

setup_environment
```

---

## 패키지 관리 시스템

(이전에 작성한 내용 포함)

### 개요

RetroPangui는 개별 코어, 에뮬레이터, Ports를 선택적으로 설치할 수 있는 패키지 관리 시스템을 제공합니다.

### 자동 스캔 시스템

`get_all_packages` 함수가 `scriptmodules/retropie_setup/scriptmodules/`를 자동으로 스캔하여:
- libretrocores/*.sh
- emulators/*.sh
- ports/*.sh
- 등의 모든 모듈을 감지

### install_module 함수

5단계 실행: depends → sources → build → install → configure

### 직접 호출 방식

```bash
sudo ./retropangui_setup.sh install_module "snes9x" "libretrocores"
```

---

## 지원 시스템

### 주요 콘솔

| 시스템 | 제조사 | 추천 코어 | 출시년도 |
|--------|--------|-----------|----------|
| NES | Nintendo | nestopia, fceumm, mesen | 1983 |
| SNES | Nintendo | snes9x, bsnes, mesen_s | 1990 |
| Mega Drive | Sega | genesisplusgx, picodrive | 1988 |
| PlayStation | Sony | pcsx_rearmed, beetle_psx, swanstation | 1994 |
| Nintendo 64 | Nintendo | mupen64plus_next, parallel_n64 | 1996 |
| Dreamcast | Sega | flycast, flycast-next | 1998 |

(전체 목록은 systemlist.csv 참조)

---

## 시스템 요구사항

### 하드웨어

| 항목 | 최소 | 권장 |
|------|------|------|
| CPU | x86_64 / aarch64 | 4코어 이상 |
| RAM | 2GB | 4GB 이상 |
| 저장공간 | 10GB | 50GB 이상 |
| GPU | OpenGL 지원 | OpenGL 3.0+ |

### 소프트웨어

| 항목 | 요구사항 |
|------|----------|
| OS | Debian 12, Ubuntu 22.04+ |
| Kernel | Linux 4.x 이상 |
| GCC | 7.x 이상 |
| CMake | 3.10 이상 |

---

## 설치 가이드

### 전체 설치 (권장)

```bash
cd ~/scripts
git clone https://github.com/LeonardWard/retropangui.git
cd retropangui
chmod +x retropangui_setup.sh
sudo ./retropangui_setup.sh
# "1. Base System 설치" 선택
```

### 개별 설치

```bash
# RetroArch만
source scriptmodules/config.sh
source scriptmodules/install_base_2_in_5_ra.sh

# EmulationStation만
source scriptmodules/install_base_3_in_5_es.sh

# 특정 코어만
sudo ./retropangui_setup.sh install_module "snes9x" "libretrocores"
```

---

## 사용 가이드

### ROM 추가

```bash
cp game.sfc ~/share/roms/snes/
```

### BIOS 추가

```bash
cp scph5501.bin ~/share/bios/
```

### 설정 변경

```
Start → UI SETTINGS
```

---

## 디렉토리 구조

### 프로젝트

```
/home/pangui/scripts/retropangui/
├── retropangui_setup.sh
├── handover_retropangui.md
├── README.md
├── log/
├── resources/
├── docs/
└── scriptmodules/
    ├── config.sh
    ├── func.sh
    ├── helpers.sh
    ├── ui.sh
    ├── packages.sh
    ├── inifuncs.sh
    ├── systemlist.csv
    ├── es_systems_generator.sh
    ├── install_base_*.sh
    ├── system_install.sh
    ├── ext_retropie_*.sh
    └── retropie_setup/
```

### 런타임

```
/opt/retropangui/
├── bin/
└── libretro/cores/

~/share/
├── roms/
├── bios/
└── system/configs/cores/

~/.emulationstation/
~/.config/retroarch/
```

---

## 개발 현황

### v0.9.2

**완성:**
- 논리 버튼 매핑
- ShowFolders
- 다국어
- 멀티코어 시스템
- 5단계 자동 설치
- 패키지 관리

**미완성:**
- 코어 선택 UI
- 메뉴 재편
- 일부 코어 빌드

---

## 로드맵

**v1.0**: 코어 선택 UI, 전체 코어 검증
**v1.5**: 스크린샷, Scraper, Netplay
**v2.0**: 웹 도구, 클라우드

---

## 트러블슈팅

### 빌드 실패

```bash
# 로그 확인
tail -f ~/scripts/retropangui/log/retropangui_*.log

# 의존성 재설치
sudo ./retropangui_setup.sh
# "1. Base System 설치" → 1단계만 재실행
```

### ES 실행 안됨

```bash
# es_systems.xml 확인
cat ~/.emulationstation/es_systems.xml

# 재생성
rm ~/.emulationstation/es_systems.xml
emulationstation  # 자동 재생성
```

---

## 기여하기

### 개발 규칙

- `scriptmodules/retropie_setup/`은 읽기 전용
- 스크립트 200줄 초과 시 분리
- `log_msg` 활용
- 주석 수정 금지

---

## 라이선스

GPL-3.0 - Copyright (C) 2025 LeonardWard

---

## 크레딧

**개발자**: LeonardWard
**참고**: RetroPie, Recalbox, Batocera, Libretro

**GitHub**: https://github.com/LeonardWard/retropangui

[⬆️ 맨 위로](#retropangui)

---

# Part 3: 최신 개발 이력 (2025-10-26 ~ 2025-11-08)

> 출처: 기존 `HANDOVER_ARCHIVE.md` (최종 업데이트: 2025-11-08)

---

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