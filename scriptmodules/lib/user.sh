#!/usr/bin/env bash
#
# 파일명: user.sh
# 사용자 및 권한 관리 함수들
# ===============================================

# 유효 사용자 가져오기
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

# 디렉토리 생성 및 유효 사용자에게 소유권 설정 (재사용 가능한 함수)
set_dir_ownership_and_permissions() {
    local dir_path="$1"
    local target_user="$(get_effective_user)"

    if [[ -z "$target_user" ]]; then
        log_msg WARN "유효 사용자 이름 결정 실패. 'root'로 설정합니다."
        target_user="root"
    fi

    # 디렉토리 생성 및 소유권 설정 (권한 문제 방지)
    sudo mkdir -p "$dir_path" || { log_msg ERROR "디렉토리 생성 실패: $dir_path"; return 1; }
    sudo chown -R "$target_user":"$target_user" "$dir_path" || { log_msg ERROR "소유권 설정 실패: $dir_path"; return 1; }

    # 호출하는 함수에서 파일 소유권 설정을 위해 target_user를 반환 (출력)
    echo "$target_user"
    return 0
}
