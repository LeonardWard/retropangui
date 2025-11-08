#!/usr/bin/env bash
#
# 파일명: git.sh
# Git 관련 함수들
# ===============================================

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
        # 기존 저장소: pull (progress 출력 강제, 원래 디렉토리 유지)
        git -C "$dest_dir" pull --ff-only --progress
    else
        # 새 저장소: clone (progress 출력 강제)
        git clone --progress "$@" "$repo_url" "$dest_dir"
    fi
}

# Git 업데이트 체크 함수
function git_check_update() {
    local repo_path="$1"

    if [[ ! -d "$repo_path/.git" ]]; then
        echo "not_a_repo"
        return 1
    fi

    # 원격 저장소 정보 업데이트
    git -C "$repo_path" fetch origin >/dev/null 2>&1 || {
        echo "fetch_failed"
        return 1
    }

    # 로컬과 원격 브랜치 비교
    local local_commit=$(git -C "$repo_path" rev-parse HEAD 2>/dev/null)
    local remote_commit=$(git -C "$repo_path" rev-parse @{u} 2>/dev/null)

    if [[ "$local_commit" != "$remote_commit" ]]; then
        echo "update_available"
        return 0
    else
        echo "up_to_date"
        return 0
    fi
}
