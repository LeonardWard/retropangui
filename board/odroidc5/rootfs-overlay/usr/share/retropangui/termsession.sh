#!/bin/sh
# terminal.sh가 kmscon --login으로 실행하는 실제 세션 스크립트.
#
# 2026-07-08: kmscon이 --login 자식 프로세스에 대해 환경을 새로 구성하고
# 호출 시점(terminal.sh)의 환경을 그대로 안 물려줌을 실기기에서 확인
# (LANG이 /proc/<pid>/environ에 아예 없었음) - PS1/ENV도 같은 이유로
# terminal.sh에서 export해봐야 여기까지 안 넘어옴(실제로 프롬프트가
# 커스텀 PS1이 아니라 uim-fep 기본값 "~ #"로 나오고 있었음, 스크린샷으로
# 확인). 그래서 필요한 환경변수는 전부 여기서 다시 지정함.
export LANG=ko_KR.UTF-8
export LC_ALL=ko_KR.UTF-8
export SHELL=/bin/sh
export PS1="$(whoami)@$(hostname):"'$(_rpui_shortpwd)'"# "
export ENV=/usr/share/retropangui/termrc.sh

# 2026-07-08: 환영 배너를 fbcon(kmscon 진입 "전")에서 kmscon 안(진입 "후")
# 으로 이동 - fbcon 커널 콘솔 폰트엔 한글 글리프가 없어 영문으로만 가능했지만,
# kmscon은 freetype+Pretendard로 직접 그리므로 한글 배너가 가능해짐.
printf '\033[1;36m'
cat << 'BANNER'
  ____      _             ____                   _   _ ___
 |  _ \ ___| |_ _ __ ___ |  _ \ __ _ _ __   __ _| | | |_ _|
 | |_) / _ \ __| '__/ _ \| |_) / _` | '_ \ / _` | | | || |
 |  _ <  __/ |_| | | (_) |  __/ (_| | | | | (_| | |_| || |
 |_| \_\___|\__|_|  \___/|_|   \__,_|_| |_|\__, |\___/|___|
                                           |___/
BANNER
printf '\033[0m\033[32m'
echo "   터미널 유틸리티"
printf '\033[0m'
echo "   종료: SELECT + START   |   스크린샷: SELECT + L1(pageup)"
echo

exec uim-fep -u byeoru
