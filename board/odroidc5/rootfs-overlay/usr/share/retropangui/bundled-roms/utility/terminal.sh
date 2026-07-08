#!/bin/sh
# 유틸리티 시스템(ES에서 "롬"처럼 실행됨) — 인터랙티브 셸 진입점.
# npm install -g로 설치한 AI CLI(Claude Code, Gemini CLI, Codex CLI 등)를
# 여기서 직접 실행하거나, 사용자가 원하는 프로그램을 위해 이 파일을
# 복사해서 자기만의 바로가기(.sh)를 만들 수 있음(2026-07-05).
#
# 주의: 파일명은 반드시 영문/ASCII로 유지할 것 — Buildroot가 재현
#가능한 빌드를 위해 전역 LC_ALL=C를 강제해서(buildroot/Makefile:248),
# squashfs 이미지에 한글 파일명이 그대로 들어가면 "?????.sh"처럼
# 깨짐(2026-07-05 실기기에서 발견, 원본 소스 파일명을 "터미널.sh"로
# 만들었다가 terminal.sh로 개명). 화면에 표시할 한글 이름은 파일명이
# 아니라 같은 폴더의 gamelist.xml <name> 태그로 지정(파일 "내용"은
# 인코딩 문제 없음, 파일"명"만 문제).
#
# ES는 FileData::launchGame()에서 system()(fork+exec+wait)으로 이 스크립트를
# 실행함 — ES 프로세스 자체는 살아있고 대기만 함(RetroArch의 execvp 자기교체
# 방식과 다름). launchGame()이 실행 직전 Window::deinit()→Renderer::deinit()
# 으로 SDL/DRM을 이미 정리해두므로 화면 전환 자체는 문제없지만, ES가 백그라운드
# (&)로 실행되면서 shell의 job control이 자동으로 stdin을 /dev/null로 돌려놔서
# (2026-07-05 실기기 확인: /proc/<es_pid>/fd/0 -> /dev/null) 이 스크립트가
# 그대로 상속받은 stdin도 /dev/null — 셸이 첫 입력을 시도하자마자 EOF를 만나
# 즉시 종료되고 ES로 복귀해버리는 버그가 있었음. 실제 콘솔(VT1)로 명시적
# 재연결해서 해결.
exec < /dev/tty1 > /dev/tty1 2>&1

# 2026-07-06: TERM 미설정 + 화면 미소거로 인한 문제 수정.
# - TERM 없이 진입하면 vim/nano/htop 등 ncurses 기반 프로그램이 제대로 초기화
#   못 함. fbcon(DRM 위 프레임버퍼 콘솔)이라 terminfo의 "linux" 항목이 맞음.
# - ES(SDL_KMSDRM)가 DRM master를 쥐고 있다가 이 스크립트 실행 시점에 VT로
#   돌아오는데, 화면을 안 지우면 이전 fbcon 버퍼 잔상 위에 프롬프트가 찍혀서
#   커서/백스페이스 위치가 어긋나 보임 - clear로 명시적으로 지움.
export TERM=linux

# 2026-07-06: "시스템 메시지가 화면에 같이 찍힌다"는 피드백 - 부팅 커맨드라인에
# `console=tty1`이 있어서(실기기 /proc/cmdline 확인) 커널 printk가 이 VT로도
# 그대로 나옴. ES가 DRM(KMS) 그래픽 모드로 화면을 그리는 동안엔 안 보이다가,
# 이 스크립트처럼 fbcon 텍스트 모드로 내려오면 그제서야 실시간으로 섞여 보임.
# VT 번호를 바꿔도(어차피 console=tty1 고정이라) 근본 해결이 안 되므로, 세션
# 동안만 콘솔 로그레벨을 낮추고 끝나면 원래 값으로 복원.
OLD_PRINTK=$(awk '{print $1}' /proc/sys/kernel/printk 2>/dev/null)
echo 1 > /proc/sys/kernel/printk 2>/dev/null

# 2026-07-06: 기본 콘솔 폰트(커널 내장 8x16)가 1920x1080에서 너무 작아 보인다는
# 피드백 - kbd 패키지의 iso01-12x22(가로 12/세로 22, 기본 대비 가로 1.5배·세로
# 1.375배)로 교체. setfont는 .gz 압축 폰트를 그대로 인식함. 이 배너 자체는
# kmscon 진입 "전"에 순수 fbcon 텍스트 모드로 찍히는 거라 이 설정이 적용됨
# (kmscon은 자기 자신의 freetype 렌더링을 쓰므로 이 설정과 무관).
setfont /usr/share/consolefonts/iso01-12x22.psfu.gz 2>/dev/null

clear

# 2026-07-06: 화면이 왼쪽 끝에 딱 붙어 나온다는 피드백 - fbcon(리눅스 콘솔)은
# DRM 커넥터에 진짜 여백(오버스캔/margin) 속성이 없어서(실기기 sysfs 확인,
# HDMI 커넥터에 underscan류 속성 자체가 없음) 완전한 해결은 어려움. 배너만
# 최소한의 여백을 두고, 프롬프트/실제 입력줄은 여전히 0열에서 시작함 - 아래
# PS1도 마찬가지.
printf '\n'

# 환영 배너 - fbcon은 표준 VT100/ANSI 이스케이프를 그대로 지원(별도 터미널
# 에뮬레이터 불필요, 조사 확인됨). figlet 미설치라 아스키아트는 고정 텍스트.
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
echo "   Terminal Utility"
printf '\033[0m'
# 2026-07-06: 이 배너 자체는 kmscon 진입 "전"에 순수 fbcon에 찍히는 거라
# 여전히 영문 유지 - fbcon 커널 콘솔 폰트엔 한글 글리프가 없음(kbd 패키지
# 폰트 포함, 실기기에서 확인). 배너 다음에 뜨는 실제 세션은 kmscon(아래)이
# 담당해서 한글이 정상적으로 보임.
echo "   Exit: SELECT + START   |   Screenshot: SELECT + L1(pageup)"
echo

# 2026-07-06: /etc/profile을 여기서 직접 한 번 읽어서 PATH/로케일 등은
# 그대로 챙기되(profile.d/*.sh는 무조건 실행됨), 이 시점엔 PS1이 비어있어서
# (system()으로 실행된 비대화형 셸이라 상속받은 PS1이 없음) profile의
# `if [ "$PS1" ]` 분기가 스킵되어 PS1='# '로 안 바뀜 - 그래서 바로 아래에서
# 안전하게 커스텀 PS1을 지정할 수 있음.
. /etc/profile

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
# 위에서 정의해봐야 아래 /bin/sh -i엔 안 보임 - ENV로 지정해두면 busybox
# ash가 비로그인 대화형 셸 시작 시 POSIX 표준대로 이 파일을 소싱해서
# _rpui_shortpwd가 그 안에서 실제로 정의됨(실기기 확인 완료).
export ENV=/usr/share/retropangui/termrc.sh

# 패드로 RA처럼 핫키 종료/스크린샷 - es_input.cfg가 이미 계산해둔 패드별
# evdev 버튼 코드를 그대로 읽어서 씀(패드마다 코드가 완전히 달라서 하드코딩
# 불가 - 예: 어떤 패드는 select가 evdev 314인데 다른 패드는 297).
# 2026-07-06: 리다이렉트 안 하면 이 스크립트의 stdout/stderr가 위
# "exec < /dev/tty1 > /dev/tty1 2>&1"을 그대로 물려받아서 rpui-termkeys.py의
# [termkeys] 로그(log() 함수, stderr 출력)가 사용자 터미널 화면에 그대로
# 찍혀 보임 - 로그 파일로 리다이렉트.
python3 /usr/share/retropangui/rpui-termkeys.py "$$" >> /var/log/rpui-termkeys.log 2>&1 &
WATCHER_PID=$!

# 2026-07-08: 한글 입출력 - 원래 fbterm(freetype/fontconfig로 화면에 그림)
# 안에서 uim-fep를 띄우는 구조였는데, fbterm이 이 기기의 DRM_FBDEV_EMULATION과
# 근본적으로 안 맞아서(실기기 확인 - 배너는 정상 출력되나 fbterm이 그래픽
# 모드로 전환하면 화면이 검게 나옴. 프레임버퍼엔 데이터가 그려지는데 실제
# 디스플레이 컨트롤러가 그 버퍼를 스캔아웃 안 하는 것으로 추정 - fbterm은
# libdrm을 아예 링크 안 하는 순수 legacy fbdev 프로그램이라 근본적 해결이
# 어려움) kmscon(DRM 네이티브 콘솔, br2-external 커스텀 패키지)으로 교체.
# 한글 자모 조합 로직(uim-fep+벼루)은 그대로 재사용 - kmscon이 화면
# 렌더링/VT 관리만 담당하고 uim-fep를 --login으로 자식 프로세스 실행시킴.
# --oneshot: uim-fep(로그인 프로세스)가 끝나면 kmscon도 같이 종료됨(fbterm이
# 셸 세션 끝나면 돌아오던 것과 동일한 동작).
# fontconfig가 Pretendard(한글 폰트)를 찾으려면 캐시가 있어야 함 - 이미
# 최신이면 fc-cache가 빠르게 넘어가므로 매번 호출해도 부담 없음.
fc-cache -f >/dev/null 2>&1

export SHELL=/bin/sh
export UIM_FEP=byeoru
kmscon --vt=/dev/tty1 --term=linux --font-size=22 --oneshot --login -- uim-fep

kill "$WATCHER_PID" 2>/dev/null

# 콘솔 로그레벨 원복 - ES로 돌아간 뒤에도 낮은 상태로 남아있으면 나중에
# 디버깅할 때 커널 메시지가 안 보여서 곤란함.
if [ -n "$OLD_PRINTK" ]; then
    echo "$OLD_PRINTK" > /proc/sys/kernel/printk 2>/dev/null
fi
