#!/bin/sh
# 공용 해상도 적용 시퀀스 - hdmi-set-resolution.py로 결정된 모드를 3단
# 폴백(지정 → 1080p → 720p)으로 odroid-drm-fbset에 적용하고, 성공한
# odroid-drm-fbset의 stdout(모드 정보 라인)을 그대로 표준출력한다(호출부가
# mpv --drm-mode 등에 쓸 WxH 추출용).
#
# 호출처(2026-07-21 통합 전에는 아래 4곳이 이 시퀀스를 각자 인라인으로
# 들고 있었음 - todo-20260713-display-followups.html 참고):
#   - S60display (부팅 1회)
#   - S99emulationstation 루프 (ES 재시작마다 - 단, 부팅 직후 첫 회차는
#     S60display가 이미 적용한 걸 EDID 해시로 확인 후 건너뜀)
#   - ES FileData.cpp (게임 종료 후 ES 복귀)
#   - ES main.cpp (SIGUSR1 모니터 핫스왑 무중단 재협상)
#
# EDID 기준선(/var/run/hdmi-edid.sha) 기록은 hdmi-set-resolution.py의
# cmd_apply()가 전담(단일 소유자, hdmi-hotplug 참고) - 이 스크립트는
# 건드리지 않는다.
#
# HDMI Content-Type을 "game"으로 신고 - 이 값을 지원하는(EDID CNC3 비트)
# TV/모니터에서 자동으로 저지연 게임모드가 켜짐. 미지원 기기에서는
# 커널이 조용히 무시함(hdmitx_sysfs_common.c의 prxcap->cnc3 체크) -
# 매 호출마다 재시도해도 안전.

HDMI_MODE="$(python3 /usr/share/retropangui/hdmi-set-resolution.py 2>>/var/log/hdmi-resolution.log)"
[ -z "${HDMI_MODE}" ] && HDMI_MODE="1080p60hz"
odroid-drm-fbset -outputmode "${HDMI_MODE}" 2>/dev/null \
    || odroid-drm-fbset -outputmode 1080p60hz 2>/dev/null \
    || odroid-drm-fbset -outputmode 720p60hz 2>/dev/null

echo game > /sys/class/amhdmitx/amhdmitx0/contenttype_mode 2>/dev/null || true
