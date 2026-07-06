# 대부분의 리눅스 배포판이 기본으로 잡아주는 관례 - 사용자 홈 밑에 개인용
# 실행파일을 두는 표준 위치. Claude Code 등 공식 설치 스크립트
# (curl -fsSL https://claude.ai/install.sh | bash)가 여기에 설치하므로
# npm 전역 설치(/opt/nodejs/bin) 대신 이 방식을 쓰면 이 PATH만으로 충분함
# (2026-07-06, 데스크탑 환경과 동일한 표준 경로를 따라가기로 함).
# 존재 여부와 상관없이 무조건 추가 - 없으면 셸이 그냥 무시하고, 로그인
# 이후 세션 중에 설치 스크립트가 새로 만들어도(예: install.sh의 mkdir -p)
# 재로그인 없이 바로 잡힘.
export PATH="$HOME/.local/bin:$PATH"
