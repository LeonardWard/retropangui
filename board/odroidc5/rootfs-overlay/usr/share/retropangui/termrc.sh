# 유틸리티 터미널의 대화형 셸(/bin/sh -i)에만 적용되는 rc 파일 - terminal.sh가
# ENV=이 경로로 지정해서 넘겨줌(busybox ash는 POSIX 표준대로 비로그인 대화형
# 셸 시작 시 $ENV를 소싱함, 실기기 확인 완료 2026-07-06).
#
# 셸 함수는 프로세스 경계를 못 넘어서(POSIX sh엔 bash의 `export -f` 같은 게
# 없음) terminal.sh에서 정의해봐야 이 자식 셸엔 안 보임 - 그래서 여기서 다시
# 정의. PS1 안에서 $(_rpui_shortpwd)로 호출되어 프롬프트 그릴 때마다 재실행됨.
_rpui_shortpwd() {
    case "$PWD" in
        "$HOME") printf '~' ;;
        "$HOME"/*) printf '~%s' "${PWD#$HOME}" ;;
        *) printf '%s' "$PWD" ;;
    esac
}
