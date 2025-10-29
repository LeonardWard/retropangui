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

## ✅ 완료된 개선 작업

### 개선 1: 코어 설치 시 es_systems.xml 자동 업데이트 ✅ (2025-10-28 완료)

**목표**: 코어 추가 설치 시 es_systems.xml에 자동으로 반영

**구현 완료**:
```
packages.sh::install_module()
  ↓
코어 설치 완료 (예: lr-pcsx-rearmed)
  ↓
update_es_systems_for_core() 자동 호출:
  - rp_module_help에서 system, extensions 추출
  - 모듈 ID: lr-pcsx-rearmed
  - .so 파일명: .installed_so_name 읽기
  ↓
es_systems.xml 업데이트:
  - add_core_to_system() 호출
  - <core name="pcsx_rearmed" module_id="lr-pcsx-rearmed" priority="999" extensions=".bin .cue" />
```

**수정된 파일**:
1. ✅ `scriptmodules/packages.sh`: update_es_systems_for_core() 함수 추가
2. ✅ `scriptmodules/es_systems_updater.sh` (신규): XML 조작 함수 모음
3. ✅ `es-app/src/SystemData.h`: CoreInfo에 `module_id` 필드 추가
4. ✅ `es-app/src/SystemData.cpp`: module_id 파싱 로직 추가
5. ✅ `es-app/src/FileData.cpp`: module_id 사용으로 하드코딩 제거

**달성된 효과**:
- ✅ 하드코딩 완전 제거 (lr- 접두사, _ → - 변환 규칙 불필요)
- ✅ 유연성 극대화 (모든 코어 이름 규칙 지원)
- ✅ 자동화 (코어 설치 시 XML 자동 업데이트)
- ✅ 호환성 (Fallback 로직으로 기존 XML 동작 보장)

---

## 🎯 향후 개선 과제

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
- `fdab176`: ES 멀티코어: module_id 도입으로 하드코딩 제거 ⭐ NEW
- `a3b53f9`: 코어 디렉토리 이름 수정 (언더스코어→하이픈)
- `910b89d`: 코어 경로 동적 탐색 (.installed_so_name 사용)
- `061f0c5`: 코어 경로 구조 수정
- `11f327b`: Settings 하드코딩 제거
- `af3abd0`: 경로 하드코딩 제거 (Settings 사용)
- `d1d68d9`: ES 멀티코어 command 템플릿 변수 치환

### retropangui
- `7e56557`: packages.sh: rp_module_help 파싱 개선 (대소문자 무시) ⭐ NEW
- `b97099b`: 핸드오버 문서 업데이트: 개선 3 완료 상태 반영
- `3367145`: 코어 설치 시스템 최종 개선: 환경변수 로드 및 추출 로직 강화
- `449cee4`: git_Pull_Or_Clone 수정: 출력 표시 및 디렉토리 변경 문제 해결
- `d1c6602`: install_base_5_in_5_setup_env.sh 정리: 불필요한 코드 제거
- `5a7a0a3`: CSV 제거 및 완전 자동화: 빈 XML + 동적 시스템/코어 생성 ⭐ 개선 3
- `f6840c3`: 설치 스크립트 구조 개선: es_systems.xml 기본 구조만 생성 ⭐ 개선 3
- `75b6a8d`: 코어 설치 시 es_systems.xml 자동 업데이트 구현 ⭐ 개선 1
- `e132668`: es_settings.cfg 형식 수정 (config 태그 제거)
- `e2085c1`: ES 설치 시 es_settings.cfg 자동 생성
- `7d97ba3`: es_systems.xml 생성에 command 템플릿 추가

---

**마지막 상태**: 개선 1, 3 완료. 핵심 기능 구현 및 테스트 완료 ✅

**테스트 체크리스트**:
- [x] ES 재빌드 성공
- [x] module_id 로그 확인 (FileData.cpp:532)
- [x] 게임 실행 정상 동작
- [x] 새 코어 설치 시 XML 자동 업데이트 확인 (2025-10-30)
  - lr-dosbox-pure: $ROMDIR (대문자) 정상 처리 ✅
  - lr-fbneo: "ROM Extension:" (s 없음) 정상 처리 ✅
  - 시스템 자동 생성 (pc, fba) 확인 ✅
- [ ] 환경변수 override 테스트 (선택사항)
- [ ] es_settings.cfg 없이 ES 실행 테스트 (선택사항)

---

## ✅ 개선 3: 설치 스크립트 구조 개선 (2025-10-30 완료)

**목표**: CSV 제거 및 완전 자동화 구현

**구현 완료**:
```
install_base_3_in_5_es.sh
  ↓
es_systems.xml 빈 구조만 생성 (<systemList></systemList>)
  ↓
install_base_4_in_5_cores.sh
  ↓
install_module() 호출 → 각 코어 설치 후 자동으로 XML 업데이트
  ↓
es_systems.xml에 module_id 포함된 정확한 코어 정보 추가
```

**수정된 파일**:
1. ✅ `install_base_3_in_5_es.sh`: 빈 es_systems.xml 생성
2. ✅ `install_base_4_in_5_cores.sh`: install_module() 사용
3. ✅ `packages.sh`: rp_module_help 파일 직접 추출
4. ✅ `es_systems_updater.sh`: config.sh 로드, 백업 최적화
5. ✅ `systemlist.csv` 삭제
6. ✅ `es_systems_generator.sh` 삭제

**달성된 효과**:
- ✅ 완전 자동화 (수동 CSV 관리 불필요)
- ✅ 중복 제거 (코어 정보가 한 곳에만 존재)
- ✅ 정확도 향상 (파일에서 직접 추출)
- ✅ 유지보수성 향상 (코어 스크립트만 관리)
