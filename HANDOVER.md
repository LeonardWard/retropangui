# RetroPangui 핸드오버 문서

**작성일**: 2025-10-26
**작업 세션**: ES 멀티코어 지원 구현

---

## 완료된 작업 요약

### 1. ES 멀티코어 지원 구조 변경
- **변경 전**: `<command>` 비어있으면 ES가 하드코딩으로 전체 명령어 생성
- **변경 후**: `<command>` 템플릿에 변수 사용, ES가 실행 시 치환

### 2. 수정된 파일들

#### retropangui-emulationstation (ES 소스)
- `es-app/src/SystemData.h`: CoreInfo 구조체 추가
- `es-app/src/SystemData.cpp`: cores 파싱 로직 추가
- `es-app/src/FileData.cpp`: %CORE%, %CONFIG% 변수 치환 로직
- `es-core/src/Settings.cpp`: 경로 기본값을 빈 문자열로 변경

#### retropangui (메인 저장소)
- `scriptmodules/es_systems_generator.sh`: command 템플릿 추가
- `scriptmodules/install_base_3_in_5_es.sh`: es_settings.cfg 자동 생성

### 3. 현재 동작 방식
```
게임 실행 요청
  ↓
es_systems.xml 확인
  <command>/opt/retropangui/bin/retroarch -L %CORE% --config %CONFIG% %ROM%</command>
  ↓
FileData.cpp::launchGame()에서 변수 치환:
  - %CORE% → 게임 확장자 기반으로 코어 선택 → 전체 경로 생성
  - %CONFIG% → 시스템 이름 기반으로 설정 경로 생성
  ↓
실행: /opt/retropangui/bin/retroarch -L /opt/retropangui/libretrocores/lr-pcsx-rearmed/pcsx_rearmed_libretro.so ...
```

---

## 🚨 임시 해결책 (하드코딩된 부분)

### 문제 1: 코어 디렉토리 이름 규칙 하드코딩
**위치**: `es-app/src/FileData.cpp:527-529`

```cpp
std::string coreName = selectedCore;
std::replace(coreName.begin(), coreName.end(), '_', '-');
std::string coreDir = coresPath + "/lr-" + coreName;
```

**문제점**:
- `lr-` 접두사 하드코딩
- 언더스코어(`_`) → 하이픈(`-`) 변환 규칙 하드코딩
- 코어 이름(예: `pcsx_rearmed`)과 모듈 ID(예: `lr-pcsx-rearmed`)가 다른데 변환 규칙으로 처리

**영향**:
- 규칙이 다른 코어는 작동 안 함
- 모듈 ID 변경 시 코드 수정 필요

### 문제 2: es_settings.cfg 수동 생성 필요
**위치**: `scriptmodules/install_base_3_in_5_es.sh:54-59`

**문제점**:
- ES 설치 시 기본 3개 경로만 작성
- ES가 저장할 때 다른 설정과 함께 덮어쓸 위험
- 현재는 `<config>` 태그 없이 최상위 레벨에 `<string>` 노드 배치

**임시 해결**: 수동으로 올바른 포맷 생성 완료
```bash
cat > ~/.emulationstation/es_settings.cfg <<'EOF'
<?xml version="1.0"?>
<string name="RetroArchPath" value="/opt/retropangui/bin/retroarch" />
<string name="LibretroCoresPath" value="/opt/retropangui/libretrocores" />
<string name="CoreConfigPath" value="/home/pangui/share/system/configs/cores" />
EOF
```

---

## 🎯 향후 개선 과제

### 개선 1: 코어 설치 시 es_systems.xml 자동 업데이트

**목표**: 코어 추가 설치 시 es_systems.xml에 자동으로 반영

**설계**:
```
packages.sh::install_module()
  ↓
코어 설치 완료 (예: lr-pcsx-rearmed)
  ↓
실제 설치된 정보 수집:
  - 모듈 ID: lr-pcsx-rearmed
  - .so 파일명: .installed_so_name 읽기
  - 지원 확장자: systemlist.csv 참조
  ↓
es_systems.xml 업데이트:
  - 해당 시스템(psx) 찾기
  - <cores> 섹션에 추가:
    <core name="pcsx_rearmed" module_id="lr-pcsx-rearmed" priority="2" extensions=".cue .bin" />
```

**수정 필요 파일**:
1. `scriptmodules/packages.sh`: install_module() 끝에 업데이트 로직 추가
2. `scriptmodules/es_systems_updater.sh` (신규): XML 업데이트 함수 모음
3. `es-app/src/SystemData.h`: CoreInfo에 `module_id` 필드 추가
4. `es-app/src/FileData.cpp`: `module_id` 사용하여 디렉토리 찾기

**장점**:
- 하드코딩 완전 제거
- 유연성 극대화
- 설치된 코어만 반영 (정확성)

### 개선 2: Settings 경로 관리 개선

**옵션 A**: 환경변수 사용
```cpp
const char* env = std::getenv("LIBRETRO_CORE_PATH");
mStringMap["LibretroCoresPath"] = env ? env : "";
```

**옵션 B**: CMake 빌드 타임 주입
```cmake
add_definitions(-DLIBRETRO_CORES_PATH="${LIBRETRO_CORE_PATH}")
```

**옵션 C**: ES 실행 래퍼 스크립트
```bash
#!/bin/bash
export LIBRETRO_CORE_PATH="/opt/retropangui/libretrocores"
exec /opt/retropangui/bin/emulationstation.real "$@"
```

---

## 📝 관련 파일 및 위치

### 설정 파일
- `~/.emulationstation/es_settings.cfg`: ES 설정 (경로 포함)
- `~/.emulationstation/es_systems.xml`: 시스템 및 코어 정의
- `/home/pangui/scripts/retropangui/scriptmodules/config.sh`: 환경변수 정의

### 코어 설치 구조
```
/opt/retropangui/libretrocores/
  ├── lr-pcsx-rearmed/
  │   ├── .installed_so_name           # "pcsx_rearmed_libretro.so"
  │   └── pcsx_rearmed_libretro.so
  ├── lr-snes9x/
  │   ├── .installed_so_name
  │   └── snes9x_libretro.so
  ...
```

### 코어 설정 구조
```
/home/pangui/share/system/configs/cores/
  ├── psx/
  │   └── retroarch.cfg
  ├── snes/
  │   └── retroarch.cfg
  ...
```

---

## 🔧 다음 세션 시작 시

1. **이 문서 읽기**: 컨텍스트 파악
2. **현재 상태 확인**:
   ```bash
   cd /home/pangui/scripts/retropangui
   git log --oneline -10
   cd /home/pangui/scripts/retropangui-emulationstation
   git log --oneline -5
   ```
3. **테스트 상태 확인**: 게임 실행이 되는지 확인
4. **개선 작업 진행**: 위의 "향후 개선 과제" 참조

---

## 커밋 히스토리

### retropangui-emulationstation
- `a3b53f9`: 코어 디렉토리 이름 수정 (언더스코어→하이픈)
- `910b89d`: 코어 경로 동적 탐색 (.installed_so_name 사용)
- `061f0c5`: 코어 경로 구조 수정
- `11f327b`: Settings 하드코딩 제거
- `af3abd0`: 경로 하드코딩 제거 (Settings 사용)
- `d1d68d9`: ES 멀티코어 command 템플릿 변수 치환

### retropangui
- `e132668`: es_settings.cfg 형식 수정 (config 태그 제거)
- `e2085c1`: ES 설치 시 es_settings.cfg 자동 생성
- `7d97ba3`: es_systems.xml 생성에 command 템플릿 추가

---

**마지막 상태**: ES 재빌드 대기 중, 게임 실행 테스트 필요
