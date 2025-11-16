# 언어 설정 / Language Settings

Retro Pangui는 시스템 로케일에 따라 자동으로 언어를 감지합니다.

Retro Pangui automatically detects language based on system locale.

## 지원 언어 / Supported Languages

- **한국어** (ko_KR.UTF-8)
- **English** (en_US.UTF-8, default)

## 언어 확인 / Check Current Language

```bash
echo $LANG
```

## 언어 변경 / Change Language

### 방법 1: 커맨드라인 옵션 (권장) / Method 1: Command-line Option (Recommended)

**한국어로 실행 / Run in Korean:**
```bash
sudo ./retropangui_setup.sh --lang=ko
# 또는 / or
sudo ./retropangui_setup.sh --korean
```

**영어로 실행 / Run in English:**
```bash
sudo ./retropangui_setup.sh --lang=en
# 또는 / or
sudo ./retropangui_setup.sh --english
```

**테스트 스크립트 / Test Script:**
```bash
./test_platform_detection.sh --lang=en
./test_platform_detection.sh --lang=ko
```

### 방법 2: 환경 변수 / Method 2: Environment Variable

**한국어로 실행 / Run in Korean:**
```bash
RETROPANGUI_LANG=ko sudo ./retropangui_setup.sh
```

**영어로 실행 / Run in English:**
```bash
RETROPANGUI_LANG=en sudo ./retropangui_setup.sh
```

### 방법 3: 시스템 로케일 (임시) / Method 3: System Locale (Temporary)

**한국어로 실행 / Run in Korean:**
```bash
LANG=ko_KR.UTF-8 sudo ./retropangui_setup.sh
```

**영어로 실행 / Run in English:**
```bash
LANG=en_US.UTF-8 sudo ./retropangui_setup.sh
```

### 언어 우선순위 / Language Priority

```
1. 커맨드라인 옵션 (--lang=en)
   ↓
2. 환경 변수 (RETROPANGUI_LANG=en)
   ↓
3. 시스템 로케일 ($LANG)
   ↓
4. 기본값 (English)
```

### 영구 변경 / Permanent Change

**한국어 / Korean:**
```bash
# Debian/Ubuntu
sudo dpkg-reconfigure locales
# ko_KR.UTF-8 선택

# 또는 직접 설정
sudo update-locale LANG=ko_KR.UTF-8
source /etc/default/locale
```

**영어 / English:**
```bash
sudo update-locale LANG=en_US.UTF-8
source /etc/default/locale
```

## 메시지 예시 / Message Examples

### 한국어 (Korean)

```
=========================================
플랫폼 정보
=========================================
아키텍처: x86_64
감지된 기기: x86_64
CPU 플래그: -march=native
플랫폼 플래그: x86_64 64bit x86 gl vulkan x11
플랫폼 설정 파일: x86_64.conf
설정 로드 상태: yes
RetroArch 버전: 최신
RetroArch 브랜치: master
=========================================
```

### English

```
=========================================
Platform Information
=========================================
Architecture: x86_64
Detected Device: x86_64
CPU Flags: -march=native
Platform Flags: x86_64 64bit x86 gl vulkan x11
Platform Config File: x86_64.conf
Config Loaded: yes
RetroArch Version: latest
RetroArch Branch: master
=========================================
```

## 새로운 언어 추가 / Adding New Languages

새로운 언어를 추가하려면 `scriptmodules/lib/i18n.sh` 파일을 수정하세요.

To add a new language, modify the `scriptmodules/lib/i18n.sh` file.

### 1. 언어 감지 추가 / Add Language Detection

```bash
detect_language() {
    local lang="${LANG:-en_US.UTF-8}"

    if [[ "$lang" =~ ^ko ]]; then
        echo "ko"
    elif [[ "$lang" =~ ^ja ]]; then  # 일본어 추가 예시
        echo "ja"
    else
        echo "en"
    fi
}
```

### 2. 메시지 번역 추가 / Add Message Translations

```bash
msg() {
    local key="$1"

    case "$__lang" in
        ko)
            case "$key" in
                "platform_info_title") echo "플랫폼 정보";;
                ...
            esac
            ;;
        ja)  # 일본어 번역
            case "$key" in
                "platform_info_title") echo "プラットフォーム情報";;
                ...
            esac
            ;;
        *)  # English (default)
            case "$key" in
                "platform_info_title") echo "Platform Information";;
                ...
            esac
            ;;
    esac
}
```

## 기술 정보 / Technical Information

- **파일 위치 / File Location:** `scriptmodules/lib/i18n.sh`
- **감지 방식 / Detection Method:** `$LANG` 환경 변수
- **함수 / Functions:**
  - `detect_language()` - 언어 감지 / Detect language
  - `msg(key)` - 메시지 출력 / Print message
  - `i18n(key)` - msg() 별칭 / Alias for msg()
