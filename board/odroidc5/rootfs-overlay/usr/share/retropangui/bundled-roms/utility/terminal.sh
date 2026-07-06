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
# 1.375배)로 교체. setfont는 .gz 압축 폰트를 그대로 인식함.
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
echo "   종료: SELECT + START   |   스크린샷: SELECT + L1(pageup)"
echo

# 2026-07-06: /etc/profile을 여기서 직접 한 번 읽어서 PATH/로케일 등은
# 그대로 챙기되(profile.d/*.sh는 무조건 실행됨), 이 시점엔 PS1이 비어있어서
# (system()으로 실행된 비대화형 셸이라 상속받은 PS1이 없음) profile의
# `if [ "$PS1" ]` 분기가 스킵되어 PS1='# '로 안 바뀜 - 그래서 바로 아래에서
# 안전하게 커스텀 PS1을 지정할 수 있음.
. /etc/profile

# "#" 하나만 뜨는 게 아니라 일반 리눅스 콘솔처럼 user@host:경로 형태로 -
# busybox ash는 bash의 \u/\h/\w PS1 이스케이프를 지원 안 해서(실기기 확인,
# 리터럴 그대로 출력됨) whoami/hostname은 지금 값을 미리 채워 넣고 $PWD만
# 작은따옴표로 묶어 평가를 미뤄서(프롬프트 그릴 때마다 셸이 알아서 재평가함,
# 표준 POSIX 동작) 디렉토리 이동에 따라 갱신되게 함.
export PS1="$(whoami)@$(hostname):"'$PWD'"# "

# 패드로 RA처럼 핫키 종료/스크린샷 - es_input.cfg가 이미 계산해둔 패드별
# evdev 버튼 코드를 그대로 읽어서 씀(패드마다 코드가 완전히 달라서 하드코딩
# 불가 - 예: 어떤 패드는 select가 evdev 314인데 다른 패드는 297).
python3 /usr/share/retropangui/rpui-termkeys.py "$$" &
WATCHER_PID=$!

# -l(로그인 셸)이 아니라 -i(대화형)만 사용 - 로그인 셸이면 /etc/profile을
# 또 실행해서 위에서 어렵게 맞춰둔 PS1이 '# '로 도로 덮어써짐(profile은
# "PS1이 비어있지 않으면 무조건 재설정"하는 방식이라 상속 여부와 무관하게
# 덮어씀). exec로 자기 자신을 치환하지도 않음 - 셸이 끝나야 워처를 정리하고
# 이 스크립트도 정상 종료해서 ES로 복귀함.
/bin/sh -i

kill "$WATCHER_PID" 2>/dev/null

# 콘솔 로그레벨 원복 - ES로 돌아간 뒤에도 낮은 상태로 남아있으면 나중에
# 디버깅할 때 커널 메시지가 안 보여서 곤란함.
if [ -n "$OLD_PRINTK" ]; then
    echo "$OLD_PRINTK" > /proc/sys/kernel/printk 2>/dev/null
fi
