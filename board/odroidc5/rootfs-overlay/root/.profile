# 2026-07-09: 유틸리티 터미널(kmscon) 진입점.
#
# kmscon의 --login/login=으로 커스텀 프로그램을 "직접" 지정하면(예:
# login=/usr/share/retropangui/termsession.py) 터미널 행/열이 24x80으로
# 고정되는 버그가 있음을 실기기에서 확인 - font-size를 16/22/38/50/미지정
# 등 뭘 바꿔도 stty size가 항상 "24 80"이었음. 반면 kmscon이 --login 없이
# 자기 기본값(/bin/login -p)으로 로그인 프로세스를 띄우면 정상적으로 큰
# 크기(54x128 실측)가 나옴 - kmscon 소스(uim-fep 아님, kmscon 자체)의
# "커스텀 login= 처리 경로"와 "기본 /bin/login 폴백 경로"가 서로 다르게
# 짜여있어서 생기는 차이로 추정(원인 코드까지는 미확인).
#
# 그래서 kmscon.conf의 login=을 "/bin/login -f root"로 지정 - 실제
# /bin/login을 그대로 써서 정상 크기 경로를 타되, "-f"(이미 인증됨, 인증
# 생략)로 비밀번호 프롬프트 없이 바로 셸로 들어가게 함. 이 .profile은 그
# 로그인 셸이 시작될 때(POSIX 표준, ash도 지원) 자동으로 소스됨 - 여기서
# 배너 출력 + 한글 입력기(uim-fep) 실행까지 담당.
export LANG=ko_KR.UTF-8
export LC_ALL=ko_KR.UTF-8
export SHELL=/bin/sh
# "#" 하나만 뜨는 게 아니라 일반 리눅스 콘솔처럼 user@host:경로 형태로 -
# busybox ash는 bash의 \u/\h/\w PS1 이스케이프를 지원 안 해서(실기기 확인,
# 리터럴 그대로 출력됨) whoami/hostname은 지금 값을 미리 채워 넣음. 경로는
# 홈 디렉토리를 ~로 줄여 보여주는 일반 리눅스 관례까지 맞추려고(bash의
# ${PWD/#$HOME/~} 같은 슬래시 치환 문법은 busybox ash가 지원 안 해서 실기기
# 확인 후 POSIX 표준 case문 기반 함수로 대체) termrc.sh의 _rpui_shortpwd
# 함수를 씀 - PS1 안에서 $(...)로 감싸 프롬프트 그릴 때마다 재실행되게 함
# (작은따옴표로 묶어 지금 당장 평가되지 않게 함, $PWD와 같은 원리).
export PS1="$(whoami)@$(hostname):"'$(_rpui_shortpwd)'"# "
# 셸 함수는 프로세스 경계를 못 넘어서(POSIX sh엔 bash의 export -f가 없음)
# 위에서 정의해봐야 아래 대화형 셸엔 안 보임 - ENV로 지정해두면 busybox
# ash가 비로그인 대화형 셸 시작 시 POSIX 표준대로 이 파일을 소싱해서
# _rpui_shortpwd가 그 안에서 실제로 정의됨.
export ENV=/usr/share/retropangui/termrc.sh

# 환영 배너 - kmscon(freetype+Pretendard)이 직접 그리므로 한글 배너 가능
# (예전 fbterm 시절엔 kmscon 진입 "전" fbcon 단계에서 찍혔고 fbcon 커널
# 콘솔 폰트엔 한글 글리프가 없어 영문만 가능했음).
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

# 2026-07-09: uim-fep가 시작 시점에 ioctl(TIOCGWINSZ)로 터미널 크기를
# 한 번만 읽어서(uim-fep 소스 fep/uim-fep.c의 get_winsize()) 자기 자식
# pty에 그대로 복사하는데, .profile 진입 직후 곧바로 실행하면 kmscon이
# 아직 이 pty의 크기 협상을 다 안 끝낸 시점이라 uim-fep가 작은 값(23x80
# 근방)을 읽어가버림을 실기기에서 확인(sleep 없이 23x80, 1초 후 53x128로
# 정상). 근본 원인(kmscon의 정확한 협상 완료 시점)까지는 못 찾았지만,
# 짧은 지연으로 확실하게 우회됨.
sleep 1
uim-fep -u byeoru
