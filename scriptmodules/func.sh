#!/usr/bin/env bash
#
# 파일명: func.sh
# 공용 기능 함수 모음, 사용자 정보 가져오기 함수
# 우선순위: $__user (core.sh에서 설정) > SUDO_USER > 현재 사용자
# ===============================================

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

# .sh 설정 파일의 변수 값을 변경하는 함수
# 사용법: config_set "KEY" "new_value" "/path/to/config.sh"
config_set() {
    local key="$1"
    local value="$2"
    local file="$3"

    # sed에서 사용할 수 있도록 value의 특수문자를 이스케이프 처리
    local escaped_value=$(printf '%s\n' "$value" | sed -e 's/[&/]/\\&/g')

    # 파일에 키가 존재하는지 확인하고 값을 변경
    if grep -q "^${key}=" "$file"; then
        sudo sed -i "s/^${key}=.*/${key}=\"${escaped_value}\"/
    elif grep -q "^#${key}=" "$file"; then
        sudo sed -i "s/^#${key}=.*/${key}=\"${escaped_value}\"/
    else
        echo "${key}=\"${escaped_value}\"" | sudo tee -a "$file" > /dev/null
    fi
}
