# `gamelist.xml` 생성기 핸드오버 문서

이 문서는 EmulationStation용 `gamelist.xml` 파일을 생성하는 Python 스크립트 `generate_gamelist.py`에 대한 개요를 제공합니다.

## 1. 목적

`generate_gamelist.py` 스크립트는 지정된 ROM 디렉토리를 스캔하고, EmulationStation의 `es_systems.cfg` 파일에서 지원되는 ROM 확장자를 동적으로 파악하여 `gamelist.xml` 파일을 자동으로 생성합니다. 이 파일은 EmulationStation에서 게임 목록을 표시하는 데 사용됩니다.

## 2. 주요 기능

*   **디렉토리 스캔:** 지정된 루트 디렉토리와 모든 하위 디렉토리에서 ROM 파일을 재귀적으로 검색합니다.
*   **동적 ROM 확장자:** 사용자의 `es_systems.cfg` 파일을 파싱하여 EmulationStation이 지원하는 모든 ROM 확장자를 동적으로 추출합니다. 이를 통해 하드코딩된 확장자 목록 없이도 정확한 ROM 감지가 가능합니다.
*   **`gamelist.xml` 생성:** 스캔된 ROM 파일을 기반으로 `gamelist.xml` 파일을 생성합니다. 각 ROM에 대해 `<path>` 및 `<name>`(파일 이름에서 파생) 요소를 포함합니다.
*   **자동 백업:** 기존 `gamelist.xml` 파일이 있는 경우, 덮어쓰기 전에 현재 날짜와 시간을 포함하는 이름으로 자동 백업을 생성하여 데이터 손실을 방지합니다.
*   **기존 `gamelist.xml` 병합 (선택 사항):** `--merge` 플래그를 사용하면 스크립트가 기존 `gamelist.xml` 파일을 읽고, 스캔된 ROM에 대한 기존 메타데이터(설명, 이미지 등)를 보존하면서 새 ROM을 추가합니다. 스캔에서 더 이상 발견되지 않는 ROM은 결과 `gamelist.xml`에서 제거됩니다.

## 3. 사용법

스크립트는 명령줄 인수를 통해 실행됩니다.

### 필수 인수:

*   `--roms_dir`: ROM 파일을 스캔할 루트 디렉토리의 절대 경로.
*   `--es_systems_cfg_path`: `es_systems.cfg` 파일의 절대 경로.

### 선택적 인수:

*   `--output_file`: 생성될 `gamelist.xml` 파일의 이름. 기본값은 현재 디렉토리의 `gamelist.xml`입니다.
*   `--merge`: 이 플래그를 지정하면 스크립트가 기존 `gamelist.xml`과 병합하여 기존 메타데이터를 보존합니다.

### 예시:

1.  **기본 `gamelist.xml` 생성 (기존 파일 덮어쓰기, 백업 자동 생성):**
    ```bash
    python generate_gamelist.py --roms_dir "/home/user/RetroPie/roms/nes" --es_systems_cfg_path "/home/user/.emulationstation/es_systems.cfg" --output_file "nes_gamelist.xml"
    ```

2.  **기존 `gamelist.xml`과 병합 (백업 자동 생성):**
    ```bash
    python generate_gamelist.py --roms_dir "/home/user/RetroPie/roms/nes" --es_systems_cfg_path "/home/user/.emulationstation/es_systems.cfg" --output_file "nes_gamelist.xml" --merge
    ```

## 4. 제한 사항 및 향후 작업

### 현재 제한 사항:

*   **메타데이터 부족:** 스크립트는 현재 ROM의 경로와 파일 이름에서 파생된 이름만으로 `gamelist.xml`을 생성합니다. 게임 설명, 이미지 경로, 출시일, 등급 등과 같은 추가 메타데이터는 자동으로 채워지지 않습니다.
*   **시스템별 스캔 없음:** 스크립트는 `es_systems.cfg`의 모든 확장자를 사용하여 ROM을 스캔합니다. 특정 시스템(예: NES만)에 대한 ROM만 스캔하도록 필터링하는 기능은 없습니다. `roms_dir`에 단일 시스템의 ROM만 포함되어 있다고 가정합니다.

### 향후 개선 사항:

*   **메타데이터 파일 지원:** ROM 경로/파일 이름을 설명, 이미지 경로 및 기타 세부 정보에 매핑하는 별도의 메타데이터 파일(예: CSV 또는 JSON)을 읽는 기능을 추가합니다.
*   **온라인 스크래핑:** 게임 이름에 따라 온라인 데이터베이스에서 메타데이터를 가져오는 기능을 구현합니다. (현재 한국어 데이터베이스의 부족으로 인해 제한적일 수 있음)
*   **시스템별 필터링:** 사용자가 `--system` 인수를 통해 특정 시스템을 지정하여 해당 시스템의 ROM 확장자만 사용하여 스캔하도록 허용합니다.
*   **고급 XML 요소:** `gamelist.xml`에서 지원하는 `rating`, `releasedate`, `developer`, `publisher`, `genre` 등과 같은 추가 XML 요소를 지원하도록 확장합니다.

---
이것으로 `gamelist.xml` 생성기 프로그램에 대한 작업이 완료되었습니다. 추가 질문이나 수정 사항이 있으면 알려주십시오.
