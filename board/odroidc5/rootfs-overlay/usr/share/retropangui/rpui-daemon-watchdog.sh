#!/bin/sh
# rpui-daemon-watchdog.sh - 경량 데몬 크래시 감시
#
# systemd의 Restart= 없이 이 프로젝트가 쓰는 데몬들의 생존을 주기적으로
# 확인하고, 죽어있으면 해당 init 스크립트의 start로 재기동한다.
# (2026-07-12, todo-20260709-systemd-migration.html "후속 제안" 항목 구현 -
# 전체 systemd 전환 없이 Restart=의 핵심 이득만 가볍게 가져오는 목적)
#
# 감시 대상은 PID 파일 기반(각 init 스크립트가 이미 만들어두는 /run/*.pid)
# 이라 프로세스명 grep보다 정확함 - PID 파일의 PID가 실제로 살아있는지만
# 확인하고, 죽어있으면(파일은 있는데 프로세스가 없음) 재기동한다.

CHECK_INTERVAL=30
LOG_TAG="rpui-daemon-watchdog"

# "이름:PID파일:재기동용 init 스크립트" 목록
TARGETS="
rpui-wifi:/run/rpui-wifi.pid:/etc/init.d/S64rpui-wifi
rpui-bt:/run/rpui-bt.pid:/etc/init.d/S65rpui-bt
bt-audio-autoswitch:/run/btaudio-autoswitch.pid:/etc/init.d/S66btaudio
bluealsa:/run/bluealsa.pid:/etc/init.d/S41bluealsa
"

is_alive() {
    pid="$1"
    [ -n "${pid}" ] && [ -d "/proc/${pid}" ]
}

check_once() {
    for entry in ${TARGETS}; do
        name="${entry%%:*}"
        rest="${entry#*:}"
        pidfile="${rest%%:*}"
        initscript="${rest#*:}"

        [ -x "${initscript}" ] || continue

        if [ ! -f "${pidfile}" ]; then
            # PID 파일 자체가 없음 - 데몬이 애초에 시작 안 됐거나(예: BT
            # 동글 미장착) init 스크립트가 조건부로 건너뛴 정상 상태일 수
            # 있어서, 여기선 아무것도 안 함(오탐 방지 - 각 init 스크립트
            # 자신의 조건 판단을 신뢰).
            continue
        fi

        pid="$(cat "${pidfile}" 2>/dev/null)"
        if ! is_alive "${pid}"; then
            logger -t "${LOG_TAG}" "${name} 죽어있음(PID ${pid:-?}) - 재기동 시도"
            rm -f "${pidfile}"
            "${initscript}" start
        fi
    done
}

while true; do
    check_once
    sleep "${CHECK_INTERVAL}"
done
