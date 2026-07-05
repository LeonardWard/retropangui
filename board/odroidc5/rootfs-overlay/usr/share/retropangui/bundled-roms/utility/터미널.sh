#!/bin/sh
# 유틸리티 시스템(ES에서 "롬"처럼 실행됨) — 인터랙티브 셸 진입점.
# npm install -g로 설치한 AI CLI(Claude Code, Gemini CLI, Codex CLI 등)를
# 여기서 직접 실행하거나, 사용자가 원하는 프로그램을 위해 이 파일을
# 복사해서 자기만의 바로가기(.sh)를 만들 수 있음(2026-07-05).
#
# 종료(exit, Ctrl+D)하면 ES 프로세스 자체가 이 스크립트로 exec 교체돼
# 있던 상태라 함께 끝나고, S99emulationstation의 재시작 루프가 ES를
# 다시 띄움 — 별도 복귀 처리 불필요.
exec /bin/sh -l
