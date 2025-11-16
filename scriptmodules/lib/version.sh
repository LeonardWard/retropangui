#!/usr/bin/env bash

# =======================================================
# Retro Pangui Versioning Module
# 파일명: version.sh
# 설명: Git 태그를 사용하여 버전 관리를 자동화합니다.
# =======================================================

# 이 스크립트가 다른 스크립트에 의해 source될 때를 대비
if [ -z "$MODULES_DIR" ]; then
    # version.sh는 scriptmodules/lib/ 안에 있음
    # SCRIPT_DIR = /path/to/retropangui/scriptmodules/lib
    # MODULES_DIR = /path/to/retropangui/scriptmodules
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
    MODULES_DIR="$(dirname "$SCRIPT_DIR")"
    source "$MODULES_DIR/lib/log.sh"
fi

# --- 공개 함수 ---

# Git 태그에서 버전 정보를 읽어와 __version 변수를 export하는 함수
function load_version_from_git() {
    # Git 저장소 루트 디렉토리 찾기
    # ROOT_DIR이 설정되어 있으면 사용, 없으면 MODULES_DIR의 부모 디렉토리 사용
    local repo_dir="${ROOT_DIR:-$(dirname "$MODULES_DIR")}"

    # git 명령을 원래 사용자 권한으로 실행하기 위한 설정
    # sudo로 실행된 경우 파일 소유권 문제를 방지
    local git_cmd="git"
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        git_cmd="sudo -u $SUDO_USER git"
    fi

    log_msg "INFO" "Git 태그에서 버전 정보를 로드합니다."
    log_msg "DEBUG" "현재 작업 디렉토리: $(pwd)"
    log_msg "DEBUG" "ROOT_DIR: ${ROOT_DIR:-'(설정 안됨)'}"
    log_msg "DEBUG" "MODULES_DIR: ${MODULES_DIR:-'(설정 안됨)'}"
    log_msg "DEBUG" "repo_dir: $repo_dir"

    # =================== GIT DEBUG START ===================
    log_msg "DEBUG" "Git command will be run as: $git_cmd"
    log_msg "DEBUG" "Checking .git directory existence: $(ls -ld $repo_dir/.git 2>&1)"
    log_msg "DEBUG" "Current git status: $($git_cmd -C "$repo_dir" status 2>&1)"
    log_msg "DEBUG" "Current HEAD commit: $($git_cmd -C "$repo_dir" rev-parse HEAD 2>&1)"
    log_msg "DEBUG" "Listing local tags: $($git_cmd -C "$repo_dir" tag 2>&1)"
    log_msg "DEBUG" "Listing content of .git/refs/tags: $(ls -l $repo_dir/.git/refs/tags 2>&1)"
    # =================== GIT DEBUG END =====================

    local latest_version=$($git_cmd -C "$repo_dir" tag 2>/dev/null | sort -V | tail -n 1)
    log_msg "DEBUG" "로드된 태그: ${latest_version:-'(없음)'}"

    # 로컬에 태그가 없으면 원격에서 가져오기 시도
    if [ -z "$latest_version" ]; then
        log_msg "INFO" "로컬 태그가 없습니다. 원격 저장소에서 태그를 가져옵니다..."
        if $git_cmd -C "$repo_dir" fetch origin --tags >/dev/null 2>&1; then
            latest_version=$($git_cmd -C "$repo_dir" tag 2>/dev/null | sort -V | tail -n 1)
            log_msg "INFO" "원격 태그를 성공적으로 가져왔습니다."
        fi
    fi

    if [ -z "$latest_version" ]; then
        log_msg "WARN" "Git 태그를 찾을 수 없어 버전을 '0.0.0'으로 설정합니다."
        export __version="0.0.0"
    else
        # 'v' 접두사 제거
        export __version=${latest_version//v/}
    fi
    log_msg "INFO" "현재 스크립트 버전: $__version"
}

# 버전을 올리고 새로운 Git 태그를 생성 및 푸시하는 함수
function bump_version() {
    local part_to_bump=$1 # major, minor, patch
    local repo_dir="${ROOT_DIR:-$(dirname "$MODULES_DIR")}"

    # git 명령을 원래 사용자 권한으로 실행
    local git_cmd="git"
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        git_cmd="sudo -u $SUDO_USER git"
    fi

    local latest_version=$($git_cmd -C "$repo_dir" tag 2>/dev/null | sort -V | tail -n 1)

    if [ -z "$latest_version" ]; then
        # 태그가 없으면 v0.0.0을 기준으로 시작
        latest_version="v0.0.0"
    fi

    # 'v' 접두사 제거
    local version_num=${latest_version//v/}
    
    # 버전 번호를 . 기준으로 분리
    local major=$(echo "$version_num" | cut -d. -f1)
    local minor=$(echo "$version_num" | cut -d. -f2)
    local patch=$(echo "$version_num" | cut -d. -f3)

    case "$part_to_bump" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo "오류: 올바른 범프 타입(major, minor, patch)을 입력하세요."
            return 1
            ;;
    esac

    local new_version="v${major}.${minor}.${patch}"
    echo "새로운 버전: $new_version"

    # 새로운 주석 태그 생성
    if $git_cmd -C "$repo_dir" tag -a "$new_version" -m "Version $new_version release"; then
        echo "로컬에 '$new_version' 태그를 생성했습니다."
    else
        echo "오류: 태그 생성에 실패했습니다."
        return 1
    fi

    # 원격 저장소에 태그 푸시
    if $git_cmd -C "$repo_dir" push origin "$new_version"; then
        echo "원격 저장소에 '$new_version' 태그를 푸시했습니다."
    else
        echo "오류: 원격 저장소에 태그를 푸시하는 데 실패했습니다."
        $git_cmd -C "$repo_dir" tag -d "$new_version" # 실패 시 로컬 태그 롤백
        return 1
    fi

    echo "버전 $new_version 태그가 성공적으로 생성되고 푸시되었습니다."
}

# --- 스크립트 직접 실행 로직 ---

# 이 스크립트가 직접 실행되었을 때만 아래 로직을 수행
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ -z "$1" ] || [ "$1" != "bump" ]; then
        echo "사용법: $0 bump <major|minor|patch>"
        exit 1
    fi
    
    if [ -z "$2" ]; then
        echo "오류: 올바른 범프 타입(major, minor, patch)을 입력하세요."
        exit 1
    fi

    bump_version "$2"
fi