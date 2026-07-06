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
clear

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
echo "  Terminal Utility"
printf '\033[0m'
echo "  종료: SELECT + START   |   스크린샷: SELECT + L1(pageup)"
echo

# 패드로 RA처럼 핫키 종료/스크린샷 - es_input.cfg가 이미 계산해둔 패드별
# evdev 버튼 코드를 그대로 읽어서 씀(패드마다 코드가 완전히 달라서 하드코딩
# 불가 - 예: 어떤 패드는 select가 evdev 314인데 다른 패드는 297).
python3 /usr/share/retropangui/rpui-termkeys.py "$$" &
WATCHER_PID=$!

# exec로 자기 자신을 치환하지 않고 foreground로 실행 - 셸이 끝나야 워처를
# 정리하고 이 스크립트도 정상 종료해서 ES로 복귀함.
/bin/sh -l

kill "$WATCHER_PID" 2>/dev/null
