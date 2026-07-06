# npm install -g로 설치한 CLI(claude, gemini, codex 등)는 /opt/nodejs/bin 밑에
# 심볼릭 링크로 생기는데, node/npm/npx/corepack만 빌드 시점에 /usr/bin으로 개별
# 링크해뒀지 이 디렉토리 자체는 PATH에 없어서 나중에 설치한 CLI는 실행이 안 됨
# (2026-07-06, npm install -g @anthropic-ai/claude-code 후 "claude: not found"로 발견).
export PATH="/opt/nodejs/bin:$PATH"
