#!/usr/bin/env bash
#
# 파일명: config_utils.sh
# 설정 파일 유틸리티 함수
# ===============================================

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
        sudo sed -i "s/^${key}=.*/${key}=\"${escaped_value}\"" "$file"
    elif grep -q "^#${key}=" "$file"; then
        sudo sed -i "s/^#${key}=.*/${key}=\"${escaped_value}\"" "$file"
    else
        echo "${key}=\"${escaped_value}\"" | sudo tee -a "$file" > /dev/null
    fi
}
