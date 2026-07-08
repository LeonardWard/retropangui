#!/usr/bin/env python3
"""terminal.py가 kmscon --login으로 실행하는 실제 세션 스크립트.

2026-07-08: kmscon이 --login 자식 프로세스에 대해 환경을 새로 구성하고
호출 시점(terminal.py)의 환경을 그대로 안 물려줌을 실기기에서 확인
(LANG이 /proc/<pid>/environ에 아예 없었음) - PS1/ENV도 같은 이유로
terminal.py에서 지정해봐야 여기까지 안 넘어옴(실제로 프롬프트가 커스텀
PS1이 아니라 uim-fep 기본값 "~ #"로 나오고 있었음, 스크린샷으로 확인).
그래서 필요한 환경변수는 전부 여기서 다시 지정함.

kmscon --login은 이 파일을 완전히 새 프로세스로 새 PTY 위에서 exec하는
구조라 terminal.py 안의 함수 호출로는 대체 불가 - 반드시 별도 실행
파일이어야 함. 셸일 필요는 없어서(termsession.sh였으나) 파이썬으로 통일.
"""
import getpass
import os
import socket

BANNER = r"""  ____      _             ____                   _   _ ___
 |  _ \ ___| |_ _ __ ___ |  _ \ __ _ _ __   __ _| | | |_ _|
 | |_) / _ \ __| '__/ _ \| |_) / _` | '_ \ / _` | | | || |
 |  _ <  __/ |_| | | (_) |  __/ (_| | | | | (_| | |_| || |
 |_| \_\___|\__|_|  \___/|_|   \__,_|_| |_|\__, |\___/|___|
                                           |___/"""


def main():
    os.environ["LANG"] = "ko_KR.UTF-8"
    os.environ["LC_ALL"] = "ko_KR.UTF-8"
    os.environ["SHELL"] = "/bin/sh"
    # PS1의 $(_rpui_shortpwd) 부분은 지금 당장 평가하면 안 되고(busybox ash가
    # 프롬프트를 그릴 때마다 재실행해야 함) 리터럴 문자열 그대로 넘겨야 함 -
    # 파이썬 f-string이 아니라 일반 문자열 연결로 작성.
    user = getpass.getuser()
    host = socket.gethostname()
    os.environ["PS1"] = user + "@" + host + ':$(_rpui_shortpwd)# '
    os.environ["ENV"] = "/usr/share/retropangui/termrc.sh"

    # 2026-07-08: 환영 배너를 fbcon(kmscon 진입 "전")에서 kmscon 안(진입
    # "후")으로 이동 - fbcon 커널 콘솔 폰트엔 한글 글리프가 없어 영문으로만
    # 가능했지만, kmscon은 freetype+Pretendard로 직접 그리므로 한글 배너가
    # 가능해짐.
    print("\033[1;36m" + BANNER)
    print("\033[0m\033[32m   터미널 유틸리티\033[0m")
    print("   종료: SELECT + START   |   스크린샷: SELECT + L1(pageup)")
    print()

    os.execvp("uim-fep", ["uim-fep", "-u", "byeoru"])


if __name__ == "__main__":
    main()
