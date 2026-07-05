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
exec /bin/sh -l
