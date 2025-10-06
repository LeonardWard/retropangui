#!/usr/bin/env bash
# 공용 기능 함수 모음 (func.sh)

# 사용자 정보 가져오기 함수
# 우선순위: $__user (core.sh에서 설정) > SUDO_USER > 현재 사용자
get_effective_user() {
    if [[ -n "$__user" && "$__user" != "root" ]]; then
        echo "$__user"
    elif [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
        echo "$SUDO_USER"
    else
        # root라면 환경에서 가장 최근의 실제 일반 사용자를 반환
        users=$(who | awk '{print $1}' | grep -v '^root$' | sort | uniq)
        if [[ -n "$users" ]]; then
            echo "$users" | head -n 1
        else
            echo ""
        fi
    fi
}

# git 저장소 URL에서 프로젝트(폴더)명 추출 함수
get_Git_Project_Dir_Name() {
    local url="$1"
    local name="$(basename "$url")"
    # .git 확장자 제거
    name="${name%.git}"
    echo "$name"
}

# 정확한 저장소 정보 파싱 및 git clone 동작
git_Pull_Or_Clone() {
    local repo_url="$1"
    local dest_dir="$2"
    shift 2
    if [ -d "$dest_dir/.git" ]; then
        cd "$dest_dir"
        git pull --ff-only
    else
        git clone "$@" "$repo_url" "$dest_dir"
    fi
}