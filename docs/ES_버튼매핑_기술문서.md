# EmulationStation 버튼 매핑 기술 문서

**작성일:** 2025-10-23
**프로젝트:** RetroPangui
**대상:** EmulationStation (RetroPie 기반)

---

## 목차

1. [문제 정의](#1-문제-정의)
2. [해결 방안: 논리 버튼 매핑](#2-해결-방안-논리-버튼-매핑)
3. [구현 상세](#3-구현-상세)
4. [적용 방법](#4-적용-방법)
5. [향후 작업](#5-향후-작업)
6. [참고: 기각된 대안들](#6-참고-기각된-대안들)

---

## 1. 문제 정의

### 1.1 목표

EmulationStation의 A/B 버튼을 **닌텐도 스타일 (B=확인, A=취소)**로 고정하되, 사용자가 선택적으로 소니/Xbox 스타일로 변경 가능하도록 구현

### 1.2 기존 구현의 문제점

**기존 패치:** `resources/patches/es_swap_ab.patch`

```cpp
// 단순히 코드에서 a와 b를 swap
- if(config->isMappedTo("a", input))
+ if(config->isMappedTo("b", input))
```

**문제점:**

1. **조이패드 물리 매핑과 충돌**
   - `es_input.cfg`에서 이미 물리 버튼을 "a", "b"로 매핑
   - 코드에서 다시 swap → 이중 swap 발생
   - 결과: 버튼이 예상과 다르게 동작

2. **분산된 입력 처리**
   - 20개 이상의 파일에 `isMappedTo("a")`, `isMappedTo("b")` 하드코딩
   - 변경 시 모든 파일을 일일이 수정 필요
   - 유지보수 어려움

3. **확장성 부족**
   - 사용자가 레이아웃 선택 불가
   - X, Y 버튼 등 다른 버튼 역할 불명확

### 1.3 EmulationStation 입력 시스템 구조

**입력 처리 흐름:**

```
조이패드 물리 버튼
    ↓
es_input.cfg (버튼 ID → 이름 매핑)
    ↓
InputConfig::isMappedTo()
    ↓
UI 컴포넌트 (게임 실행, 메뉴 등)
```

**핵심 파일:**

- `es-core/src/InputConfig.h/cpp` - 입력 매핑 관리
- `es-core/src/InputManager.cpp` - 입력 매니저
- `es-core/src/Settings.cpp` - 설정 관리
- `es-app/src/guis/GuiMenu.cpp` - 메인 메뉴 UI

---

## 2. 해결 방안: 논리 버튼 매핑

### 2.1 핵심 개념

**물리 버튼**과 **논리 동작**을 분리:

```
물리 버튼: a, b, x, y, start, select (조이패드의 실제 버튼)
논리 동작: accept (확인), back (취소)
```

**매핑 테이블:**

| 레이아웃 | Accept | Back | 비고 |
|---------|--------|------|------|
| nintendo | b | a | 닌텐도, SNES 스타일 (기본) |
| sony | a | b | PlayStation, Xbox 스타일 |

**특수 버튼은 논리 매핑 제외:**

- **Start:** 항상 메뉴 열기
- **Select:** 컨텍스트별 기능 (옵션 메뉴 등)
- **X, Y:** 보조 기능 (향후 필요시 추가)

### 2.2 장점

✅ **조이패드 물리 매핑과 독립적** - 이중 swap 문제 해결
✅ **일관된 동작** - 모든 화면에서 동일하게 적용
✅ **중앙 집중화** - InputConfig 한 곳에서 관리
✅ **확장 가능** - 다른 버튼도 쉽게 추가
✅ **사용자 선택** - UI에서 레이아웃 변경 가능

---

## 3. 구현 상세

### 3.1 InputConfig 확장

#### 3.1.1 헤더 파일 (`es-core/src/InputConfig.h`)

```cpp
class InputConfig
{
public:
    // 기존 메서드
    bool isMappedTo(const std::string& name, Input input);

    // ★ 새 메서드: 논리 동작 체크
    bool isMappedToAction(const std::string& action, Input input);

    // ★ 버튼 레이아웃 관리
    static void setButtonLayout(const std::string& layout);
    static std::string getButtonLayout();
    static std::string getActionButton(const std::string& action);

private:
    std::map<std::string, Input> mNameMap;

    // ★ 논리 매핑 테이블
    static std::map<std::string, std::string> sActionMapping;
    static std::string sButtonLayout;
};
```

#### 3.1.2 구현 파일 (`es-core/src/InputConfig.cpp`)

```cpp
// 정적 멤버 변수 초기화
std::map<std::string, std::string> InputConfig::sActionMapping;
std::string InputConfig::sButtonLayout = "";

// 논리 매핑 초기화
void initActionMapping()
{
    InputConfig::sActionMapping.clear();

    std::string layout = Settings::getInstance()->getString("ButtonLayout");
    if (layout.empty())
        layout = "nintendo";  // 기본값

    if (layout == "nintendo")
    {
        // 닌텐도 스타일: B=확인, A=취소
        InputConfig::sActionMapping["accept"] = "b";
        InputConfig::sActionMapping["back"] = "a";
    }
    else if (layout == "sony" || layout == "xbox")
    {
        // 소니/Xbox 스타일: A=확인, B=취소
        InputConfig::sActionMapping["accept"] = "a";
        InputConfig::sActionMapping["back"] = "b";
    }

    InputConfig::sButtonLayout = layout;
    LOG(LogInfo) << "Button Layout: " << layout
                 << " (Accept=" << InputConfig::sActionMapping["accept"]
                 << ", Back=" << InputConfig::sActionMapping["back"] << ")";
}

// 논리 동작 체크
bool InputConfig::isMappedToAction(const std::string& action, Input input)
{
    // 매핑이 초기화되지 않았으면 초기화
    if (sActionMapping.empty() || sButtonLayout.empty())
        initActionMapping();

    // 논리 동작을 물리 버튼으로 변환
    auto it = sActionMapping.find(action);
    if (it != sActionMapping.end())
        return isMappedTo(it->second, input);

    // 매핑이 없으면 직접 체크 (하위 호환성)
    return isMappedTo(action, input);
}

// 버튼 레이아웃 설정
void InputConfig::setButtonLayout(const std::string& layout)
{
    Settings::getInstance()->setString("ButtonLayout", layout);
    Settings::getInstance()->saveFile();
    initActionMapping();
}

// 현재 버튼 레이아웃 조회
std::string InputConfig::getButtonLayout()
{
    if (sButtonLayout.empty())
        initActionMapping();
    return sButtonLayout;
}

// 논리 동작에 매핑된 물리 버튼 이름 조회 (Help Prompt용)
std::string InputConfig::getActionButton(const std::string& action)
{
    if (sActionMapping.empty())
        initActionMapping();

    auto it = sActionMapping.find(action);
    return (it != sActionMapping.end()) ? it->second : action;
}
```

### 3.2 Settings 기본값 추가

#### `es-core/src/Settings.cpp`

```cpp
void Settings::setDefaults()
{
    // 기존 기본값들...

    // ★ 버튼 레이아웃 기본값: 닌텐도 스타일
    mStringMap["ButtonLayout"] = "nintendo";

    // 나머지 기본값...
}
```

### 3.3 UI 메뉴 추가

#### `es-app/src/guis/GuiMenu.cpp` - `openUISettings()` 함수

```cpp
void GuiMenu::openUISettings()
{
    auto s = new GuiSettings(mWindow, "UI SETTINGS");

    // UI MODE (기존 코드)
    // ...

    // ★ 버튼 레이아웃 선택 추가
    auto button_layout = std::make_shared<OptionListComponent<std::string>>(
        mWindow, "BUTTON LAYOUT", false
    );

    std::string currentLayout = Settings::getInstance()->getString("ButtonLayout");
    if (currentLayout.empty())
        currentLayout = "nintendo";

    button_layout->add("NINTENDO (B=OK, A=BACK)", "nintendo",
                       currentLayout == "nintendo");
    button_layout->add("SONY/XBOX (A=OK, B=BACK)", "sony",
                       currentLayout == "sony");

    s->addWithLabel("BUTTON LAYOUT", button_layout);

    s->addSaveFunc([button_layout] {
        std::string selected = button_layout->getSelected();
        Settings::getInstance()->setString("ButtonLayout", selected);
        InputConfig::setButtonLayout(selected);
        LOG(LogInfo) << "Button layout changed to: " << selected;
    });

    // SCREENSAVER (기존 코드)
    // ...

    mWindow->pushGui(s);
}
```

**메뉴 위치:**
```
EmulationStation 실행
→ Start 버튼 (메인 메뉴)
→ UI SETTINGS
→ BUTTON LAYOUT
   • NINTENDO (B=OK, A=BACK) ← 기본값
   • SONY/XBOX (A=OK, B=BACK)
```

---

## 4. 적용 방법

### 4.1 패치 파일 적용

**패치 파일:** `resources/patches/es_logical_button_mapping.patch`

**적용 위치:** `scriptmodules/install_base_3_in_5_es.sh:21`

```bash
log_msg INFO "EmulationStation 논리 버튼 매핑 패치 적용 중..."
patch -p1 -d "$ES_BUILD_DIR" < "$RESOURCES_DIR/patches/es_logical_button_mapping.patch"
```

### 4.2 빌드 및 설치

```bash
cd /home/pangui/scripts/retropangui
./retropangui_setup.sh
# 또는
./develop_custom_es.sh  # 개발 빌드
```

### 4.3 확인

1. EmulationStation 실행
2. Start 버튼으로 메인 메뉴
3. **UI SETTINGS** 선택
4. **BUTTON LAYOUT** 확인

---

## 5. 향후 작업

### 5.1 현재 상태

✅ **완료:** 논리 매핑 인프라 구축
- InputConfig에 메서드 추가
- Settings 기본값 설정
- UI 메뉴 추가

⏳ **미완료:** UI 컴포넌트에서 논리 매핑 사용

### 5.2 변경이 필요한 파일

현재는 **인프라만 구축**한 상태입니다. 실제로 동작하려면 각 UI 컴포넌트에서 논리 매핑을 사용해야 합니다.

#### Accept 동작 (게임 실행, 선택 등)

**변경 전:**
```cpp
if(config->isMappedTo("a", input))
{
    // 게임 실행
}
```

**변경 후:**
```cpp
if(config->isMappedToAction("accept", input))
{
    // 게임 실행
}
```

**대상 파일 (25개):**

1. `es-app/src/views/gamelist/ISimpleGameListView.cpp` - 게임 실행
2. `es-app/src/views/SystemView.cpp` - 시스템 선택
3. `es-core/src/components/ButtonComponent.cpp` - 버튼 클릭
4. `es-core/src/components/SwitchComponent.cpp` - 스위치 토글
5. `es-core/src/components/DateTimeEditComponent.cpp` - 날짜 편집
6. `es-core/src/components/TextEditComponent.cpp` - 텍스트 편집 시작
7. `es-app/src/components/RatingComponent.cpp` - 별점 추가
8. `es-app/src/components/ScraperSearchComponent.cpp` - 스크래핑 결과
9. `es-app/src/guis/GuiGamelistOptions.cpp` - 리스트 옵션
10. `es-core/src/guis/GuiInputConfig.cpp` - 입력 설정
11. 기타 15개 파일...

#### Back 동작 (취소, 뒤로가기 등)

**변경 전:**
```cpp
if(config->isMappedTo("b", input))
{
    delete this;  // 메뉴 닫기
    return true;
}
```

**변경 후:**
```cpp
if(config->isMappedToAction("back", input))
{
    delete this;  // 메뉴 닫기
    return true;
}
```

**대상 파일 (20개):**

1. `es-app/src/guis/GuiMenu.cpp` - 메뉴 닫기
2. `es-app/src/guis/GuiSettings.cpp` - 설정 나가기
3. `es-app/src/guis/GuiMetaDataEd.cpp` - 메타데이터 편집 종료
4. `es-app/src/guis/GuiGamelistFilter.cpp` - 필터 적용
5. `es-app/src/components/AsyncReqComponent.cpp` - 비동기 요청 취소
6. `es-core/src/guis/GuiTextEditPopup.cpp` - 텍스트 팝업
7. `es-core/src/guis/GuiMsgBox.cpp` - 메시지 박스 취소
8. 기타 13개 파일...

#### Help Prompt 업데이트

화면 하단 도움말도 동적으로 표시:

**변경 전:**
```cpp
prompts.push_back(HelpPrompt("a", "launch"));
prompts.push_back(HelpPrompt("b", "back"));
```

**변경 후:**
```cpp
prompts.push_back(HelpPrompt(
    InputConfig::getActionButton("accept"),
    "launch"
));
prompts.push_back(HelpPrompt(
    InputConfig::getActionButton("back"),
    "back"
));
```

**대상 파일 (12개):**

1. `es-app/src/views/gamelist/BasicGameListView.cpp`
2. `es-app/src/views/gamelist/GridGameListView.cpp`
3. `es-core/src/components/ImageComponent.cpp`
4. `es-core/src/components/VideoComponent.cpp`
5. 기타 8개 파일...

### 5.3 자동 변환 스크립트 (준비 중)

수동 변경이 번거로우므로, 자동 변환 스크립트 작성 고려:

```bash
#!/bin/bash
# convert_to_logical_actions.sh

ES_SOURCE="scriptmodules/emulationstation-retropie-dev"

# Accept 동작 변환
find "$ES_SOURCE" -type f \( -name "*.cpp" -o -name "*.h" \) -exec sed -i \
    's/isMappedTo("a", input)/isMappedToAction("accept", input)/g' {} +

# Back 동작 변환
find "$ES_SOURCE" -type f \( -name "*.cpp" -o -name "*.h" \) -exec sed -i \
    's/isMappedTo("b", input)/isMappedToAction("back", input)/g' {} +

# Help Prompt 변환
find "$ES_SOURCE" -type f -name "*.cpp" -exec sed -i \
    's/HelpPrompt("a",/HelpPrompt(InputConfig::getActionButton("accept"),/g' {} +

find "$ES_SOURCE" -type f -name "*.cpp" -exec sed -i \
    's/HelpPrompt("b",/HelpPrompt(InputConfig::getActionButton("back"),/g' {} +
```

**주의:** 모든 `isMappedTo("a")`, `isMappedTo("b")`를 변환하므로, 특수한 경우는 수동 검토 필요

---

## 6. 참고: 기각된 대안들

### 6.1 방안 1: 단순 Swap (기존)

**개념:** 코드에서 "a"와 "b"를 단순히 교환

**문제점:**
- 조이패드 물리 매핑과 충돌 (이중 swap)
- 20개 이상 파일 수정 필요
- 유지보수 어려움

**결론:** ❌ 기각

### 6.2 방안 2: 설정 파일 자동 변환

**개념:** `es_input.cfg`에서 물리 버튼 ID를 직접 교환

```python
# swap_ab_in_config.py
a_input.set('id', b_id)
b_input.set('id', a_id)
```

**문제점:**
- 사용자가 컨트롤러 재설정하면 원래대로 복구됨
- 설정 UI에서도 혼란 발생
- 근본적인 해결책이 아님

**결론:** ❌ 기각

### 6.3 방안 3: InputManager 재매핑 (시도했으나 실패)

**개념:** `InputManager::init()`에서 모든 컨트롤러에 대해 자동 재매핑

```cpp
// InputManager.cpp
for(auto it = mInputConfigs.begin(); it != mInputConfigs.end(); it++)
{
    InputConfig* config = it->second;
    Input a_input, b_input;
    if(config->getInputByName("a", &a_input))
        config->mapInput("back", a_input);
    if(config->getInputByName("b", &b_input))
        config->mapInput("accept", b_input);
}
```

**문제점:**
- 컴파일 오류 발생 (구문 오류)
- 버튼이 전혀 작동하지 않는 문제 발생
- 디버깅 어려움

**결론:** ❌ 실패 (handover_retropangui.md 참조)

---

## 7. 테스트 시나리오

### 7.1 닌텐도 스타일 (기본)

| 화면 | 동작 | 버튼 | 확인 |
|-----|------|------|-----|
| 게임 리스트 | 게임 실행 | B | ☐ |
| 게임 리스트 | 상위 폴더 | A | ☐ |
| 시스템 선택 | 시스템 진입 | B | ☐ |
| 메인 메뉴 열기 | - | Start | ☐ |
| 메뉴 | 항목 선택 | B | ☐ |
| 메뉴 | 닫기 | A | ☐ |
| 설정 | 값 변경 | B | ☐ |
| 설정 | 나가기 | A | ☐ |

### 7.2 소니/Xbox 스타일

위와 동일, A와 B만 반대

### 7.3 특수 버튼

| 버튼 | 동작 | 변경 여부 |
|-----|------|---------|
| Start | 메뉴 열기 | 변경 없음 |
| Select | 옵션/필터 | 변경 없음 |
| X | 랜덤 게임 | 변경 없음 |
| Y | 즐겨찾기 | 변경 없음 |

---

## 8. 문제 해결

### Q1: UI SETTINGS에 BUTTON LAYOUT이 안 보입니다

**A:** GuiMenu.cpp 패치가 적용되지 않았을 수 있습니다.

```bash
grep -n "BUTTON LAYOUT" \
  scriptmodules/emulationstation-retropie-dev/es-app/src/guis/GuiMenu.cpp
```

결과가 없으면 패치 재적용 필요

### Q2: 버튼이 여전히 이상하게 동작합니다

**A:** 아직 UI 컴포넌트가 `isMappedToAction()`을 사용하지 않기 때문입니다.

현재는 **인프라만 구축**된 상태로, 실제 동작을 위해서는 [5.2 변경이 필요한 파일](#52-변경이-필요한-파일) 섹션의 작업이 필요합니다.

### Q3: 컴파일 오류가 발생합니다

**A:** 다음을 확인하세요:

1. `InputConfig.h`에 메서드 선언이 있는지
2. `InputConfig.cpp`에 구현이 있는지
3. `Settings.cpp`에 기본값이 추가되었는지

```bash
# 확인
grep "isMappedToAction" scriptmodules/emulationstation-retropie-dev/es-core/src/InputConfig.h
grep "initActionMapping" scriptmodules/emulationstation-retropie-dev/es-core/src/InputConfig.cpp
grep "ButtonLayout" scriptmodules/emulationstation-retropie-dev/es-core/src/Settings.cpp
```

---

## 9. 추가 개선 아이디어

### 9.1 더 많은 레이아웃 지원

```cpp
// 세가 메가드라이브 스타일
if (layout == "sega")
{
    sActionMapping["accept"] = "b";
    sActionMapping["back"] = "c";
}

// 사용자 정의
if (layout == "custom")
{
    sActionMapping["accept"] = Settings::getInstance()->getString("CustomAcceptButton");
    sActionMapping["back"] = Settings::getInstance()->getString("CustomBackButton");
}
```

### 9.2 시스템별 자동 레이아웃

```cpp
// PlayStation 게임은 자동으로 소니 스타일
if (currentSystem->getName() == "psx" || currentSystem->getName() == "ps2")
    InputConfig::setButtonLayout("sony");

// 닌텐도 게임은 닌텐도 스타일
else if (currentSystem->getName() == "snes" || currentSystem->getName() == "nes")
    InputConfig::setButtonLayout("nintendo");
```

### 9.3 초기 설정 마법사

컨트롤러 감지 후 버튼 레이아웃 선택:

```cpp
void GuiDetectDevice::showButtonLayoutChoice()
{
    auto msgBox = new GuiMsgBox(mWindow,
        "어떤 버튼 레이아웃을 사용하시겠습니까?\n\n"
        "닌텐도: B로 선택, A로 취소\n"
        "소니/Xbox: A로 선택, B로 취소",
        "닌텐도", [this] {
            InputConfig::setButtonLayout("nintendo");
        },
        "소니/Xbox", [this] {
            InputConfig::setButtonLayout("sony");
        }
    );
    mWindow->pushGui(msgBox);
}
```

---

## 10. 요약

### 10.1 구현 내용

✅ **InputConfig 확장**
- `isMappedToAction()` 메서드 추가
- 논리 매핑 테이블 관리
- 버튼 레이아웃 설정 함수

✅ **Settings 기본값**
- ButtonLayout = "nintendo" (기본)

✅ **UI 메뉴**
- UI SETTINGS > BUTTON LAYOUT
- 닌텐도 / 소니 선택 가능

### 10.2 향후 작업

⏳ **UI 컴포넌트 변경**
- 45개 파일에서 `isMappedTo()` → `isMappedToAction()`
- Help Prompt 업데이트
- 자동 변환 스크립트 작성 고려

### 10.3 핵심 장점

- 조이패드 물리 매핑과 독립적
- 중앙 집중화된 관리
- 사용자 선택 가능
- 확장 가능한 구조

---

**문서 끝**
