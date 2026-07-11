#!/usr/bin/env python3
"""유틸리티 시스템(ES에서 "롬"처럼 실행됨) - 인터랙티브 셸 진입점.

npm install -g로 설치한 AI CLI(Claude Code, Gemini CLI, Codex CLI 등)를
여기서 직접 실행하거나, 사용자가 원하는 프로그램을 위해 이 파일을 복사해서
자기만의 바로가기(.py)를 만들 수 있음.

2026-07-08: exFAT(share 파티션)은 유닉스 실행 권한 비트를 저장 못 해서
셰뱅+실행권한에 의존하는 방식이 불안정함 - systems.json에
"command": "python3 %ROM%"를 명시해서 인터프리터를 항상 명확히 지정.
원래 terminal.sh(셸 스크립트)였으나 exFAT 위에 스크립트를 둘 땐 파이썬으로
만들기로 함(리콜박스 등 다른 프로젝트가 같은 이유로 파이썬을 쓰는 것과
동일한 이유 - 인터프리터를 explicit하게 호출하면 셸/파이썬 어느 쪽이든
상관없지만, 파이썬이 이후 복잡한 로직 확장에 더 유리함).

주의: 파일명은 반드시 영문/ASCII로 유지할 것 - Buildroot가 재현 가능한
빌드를 위해 전역 LC_ALL=C를 강제해서(buildroot/Makefile:248), squashfs
이미지에 한글 파일명이 그대로 들어가면 "?????.py"처럼 깨짐(2026-07-05
실기기에서 발견). 화면에 표시할 한글 이름은 파일명이 아니라 같은 폴더의
gamelist.xml <name> 태그로 지정.

ES는 FileData::launchGame()에서 system()(fork+exec+wait)으로 이 스크립트를
실행함 - ES 프로세스 자체는 살아있고 대기만 함. launchGame()이 실행 직전
Window::deinit()->Renderer::deinit()으로 SDL/DRM을 이미 정리해두므로 화면
전환 자체는 문제없지만, ES가 백그라운드(&)로 실행되면서 셸의 job control이
자동으로 stdin을 /dev/null로 돌려놔서(2026-07-05 실기기 확인) 이 스크립트가
그대로 상속받은 stdin도 /dev/null - 첫 입력 시도에서 EOF를 만나 즉시
종료되고 ES로 복귀해버리는 버그가 있었음. 실제 콘솔(VT1)로 명시적
재연결해서 해결.
"""
import os
import subprocess

TTY = "/dev/tty1"
TERMKEYS_LOG = "/var/log/rpui-termkeys.log"


def reconnect_tty():
    fd = os.open(TTY, os.O_RDWR)
    os.dup2(fd, 0)
    os.dup2(fd, 1)
    os.dup2(fd, 2)
    if fd > 2:
        os.close(fd)


def read_printk_level():
    try:
        with open("/proc/sys/kernel/printk") as f:
            return f.read().split()[0]
    except OSError:
        return None


def write_printk_level(level):
    try:
        with open("/proc/sys/kernel/printk", "w") as f:
            f.write(level)
    except OSError:
        pass


def main():
    reconnect_tty()

    os.environ["TERM"] = "linux"

    # 2026-07-06: 부팅 커맨드라인에 console=tty1이 있어서 커널 printk가 이
    # VT로도 그대로 나옴 - ES가 DRM(KMS) 그래픽 모드로 화면을 그리는 동안엔
    # 안 보이다가, 이 스크립트처럼 fbcon 텍스트 모드로 내려오면 실시간으로
    # 섞여 보임. 세션 동안만 콘솔 로그레벨을 낮추고 끝나면 원래 값으로 복원.
    old_printk = read_printk_level()
    write_printk_level("1")

    # 2026-07-09: 환영 배너는 kmscon 안(root의 .profile)에서 그림 - fbcon
    # 커널 콘솔 폰트엔 한글 글리프가 없어서(PSF 비트맵, 256~512 글리프 한정)
    # 여기서는 화면만 지움.
    subprocess.run(["clear"])

    # 패드로 RA처럼 핫키 종료/스크린샷 - es_input.cfg가 이미 계산해둔 패드별
    # evdev 버튼 코드를 그대로 읽어서 씀(패드마다 코드가 완전히 달라서
    # 하드코딩 불가). stdout/stderr를 로그 파일로 분리 - 안 하면 워처의
    # [termkeys] 로그가 사용자 터미널 화면에 그대로 찍혀 보임.
    with open(TERMKEYS_LOG, "a") as log:
        watcher = subprocess.Popen(
            ["python3", "/usr/share/retropangui/rpui-termkeys.py", str(os.getpid())],
            stdout=log,
            stderr=subprocess.STDOUT,
        )

    # 2026-07-08: fontconfig가 Pretendard(한글 폰트)를 찾으려면 캐시가
    # 있어야 함 - 이미 최신이면 fc-cache가 빠르게 넘어가므로 매번 호출해도
    # 부담 없음.
    subprocess.run(["fc-cache", "-f"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # 2026-07-08: kmscon이 --use-original-mode(기본값)로 "지금 활성 상태인
    # DRM 모드"를 그대로 재사용하는데, ES/스플래시가 물러난 직후 이 VT의
    # 활성 모드가 EDID "preferred" 협상 결과인 1920x1080p120hz로 잡혀있는
    # 경우가 있어서(S99emulationstation의 스플래시 60Hz 강제와 동일한 근본
    # 원인) 예전엔 여기서 그냥 "1080p60hz"로 밀어붙였음.
    #
    # 2026-07-12 정정: 그 뒤로 해상도 체계가 EDID 기반 커스텀 모드라인
    # 등록(aml_drm 모듈)으로 바뀌어서, 연결된 모니터에 따라 활성 모드가
    # "1080p60hz" 같은 표준 CEA 프리셋이 아니라 custom_2560x1600_60hz류의
    # 커스텀 이름일 수 있음 - 그 상태에서 무작정 "1080p60hz"로 전환을
    # 시도하면 실패하고(stderr는 버려서 안 보임) 활성 모드가 그대로
    # 남아서 "해상도가 크게 잡혀있다"는 증상으로 나타남. S60display/
    # S99emulationstation과 동일하게 hdmi-set-resolution.py로 현재 설정에
    # 맞는 모드를 다시 등록+적용하도록 교체.
    try:
        hdmi_mode = subprocess.run(
            ["python3", "/usr/share/retropangui/hdmi-set-resolution.py"],
            capture_output=True, text=True,
        ).stdout.strip()
    except OSError:
        hdmi_mode = ""
    if not hdmi_mode:
        hdmi_mode = "1080p60hz"
    result = subprocess.run(
        ["odroid-drm-fbset", "-outputmode", hdmi_mode],
        stderr=subprocess.DEVNULL,
    )
    if result.returncode != 0:
        subprocess.run(
            ["odroid-drm-fbset", "-outputmode", "1080p60hz"],
            stderr=subprocess.DEVNULL,
        )

    # 2026-07-08: 한글 입출력 - fbterm은 이 기기의 DRM_FBDEV_EMULATION과
    # 근본적으로 안 맞아서(배너는 정상 출력되나 그래픽 모드 전환 시 화면이
    # 검게 나옴 - libdrm을 아예 안 링크하는 legacy fbdev 프로그램이라 근본
    # 해결 불가) kmscon(DRM 네이티브 콘솔)으로 교체.
    #
    # 2026-07-09: 커맨드라인 인자 없이 그냥 kmscon만 실행 - 모든 설정은
    # /etc/kmscon/kmscon.conf(rootfs-overlay/etc/kmscon/)에서 옴. 예전엔
    # 여기서 --font-size/--login 등을 직접 CLI로 줬는데, login=으로 커스텀
    # 프로그램(termsession.py)을 직접 지정하면 터미널 행/열이 24x80으로
    # 고정되는 kmscon 버그를 발견(font-size를 뭘로 바꿔도 stty size가 항상
    # "24 80" - 처음엔 이게 kmscon 자체의 근본 한계라고 결론 내렸었으나 틀린
    # 진단이었음, 아래 done-20260706-terminal-cjk.html의 "잘못된 진단 기록"
    # 참고). 진짜 원인은 login=/--login에 커스텀 명령을 직접 주는 코드
    # 경로 자체였고, kmscon.conf의 login=/bin/login -f root로 kmscon
    # 기본 로그인 경로를 그대로 타면서(-f로 비밀번호만 생략) 해결됨 - 실측
    # 54x128. 배너/LANG/PS1/ENV/uim-fep 실행은 이제 root의
    # .profile(rootfs-overlay/root/.profile)이 로그인 셸 시작 시 자동으로
    # 담당함(login=이 가리키는 별도 스크립트 없이).
    subprocess.run(["kmscon"])

    try:
        watcher.terminate()
        watcher.wait(timeout=3)
    except (ProcessLookupError, subprocess.TimeoutExpired):
        pass

    if old_printk is not None:
        write_printk_level(old_printk)


if __name__ == "__main__":
    main()
