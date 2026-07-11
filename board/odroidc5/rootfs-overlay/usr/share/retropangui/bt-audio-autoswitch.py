#!/usr/bin/env python3
# bt-audio-autoswitch.py
#
# 페어링된 블루투스 오디오 기기(스피커/헤드폰)가 연결되면 /etc/asound.conf의
# 기본 출력(pcm.!default/ctl.!default)을 자동으로 그 기기로 전환하고,
# 연결이 끊기면 전환 직전 상태로 되돌린다.
#
# rpui-bt 데몬이 이미 주기적으로 갱신하는 /tmp/retropangui-bt-discovery.json
# (icon/connected 필드 포함)을 그대로 읽어서 판단하므로 별도의 D-Bus 연동
# 없이 가볍게 폴링만 한다.
#
# 2026-07-11: bluez-alsa(bluealsa) 패키지 추가와 함께 구현.

import json
import os
import shutil
import time
import sys

DISCOVERY_JSON = "/tmp/retropangui-bt-discovery.json"
ASOUND_CONF = "/etc/asound.conf"
BACKUP_CONF = "/tmp/retropangui-asound-before-bt.conf"
POLL_INTERVAL_SEC = 2


def log(msg):
    print(f"[bt-audio-autoswitch] {msg}", file=sys.stderr)


def read_connected_audio_mac():
    """연결된 블루투스 오디오(icon이 audio-로 시작) 기기의 MAC을 돌려준다.
    여러 개면 첫 번째 것 하나만(동시에 여러 스피커로 나눠 낼 방법이 없으므로)."""
    try:
        with open(DISCOVERY_JSON) as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError):
        return None

    for d in data.get("devices", []):
        if d.get("connected") and str(d.get("icon", "")).startswith("audio-"):
            return d.get("mac")
    return None


def bt_audio_conf(mac):
    return (
        f'# 2026-07-11: 블루투스 오디오 기기 연결됨({mac}) - 자동 전환됨.\n'
        f'# 연결 해제되면 bt-audio-autoswitch.py가 이전 설정으로 되돌림.\n'
        f'pcm.!default {{\n'
        f'    type bluealsa\n'
        f'    device "{mac}"\n'
        f'    profile "a2dp"\n'
        f'}}\n\n'
        f'ctl.!default {{\n'
        f'    type bluealsa\n'
        f'}}\n'
    )


def switch_to_bt(mac):
    if not os.path.exists(BACKUP_CONF):
        try:
            shutil.copy2(ASOUND_CONF, BACKUP_CONF)
        except OSError as e:
            log(f"백업 실패({e}) - 전환 중단")
            return False
    try:
        with open(ASOUND_CONF, "w") as f:
            f.write(bt_audio_conf(mac))
    except OSError as e:
        log(f"asound.conf 쓰기 실패: {e}")
        return False
    log(f"블루투스 오디오로 전환: {mac}")
    return True


def switch_back():
    if not os.path.exists(BACKUP_CONF):
        return
    try:
        shutil.copy2(BACKUP_CONF, ASOUND_CONF)
        os.remove(BACKUP_CONF)
    except OSError as e:
        log(f"복원 실패: {e}")
        return
    log("블루투스 오디오 연결 해제 - 이전 출력으로 복원")


def main():
    current_mac = None
    while True:
        mac = read_connected_audio_mac()
        if mac != current_mac:
            if mac:
                if switch_to_bt(mac):
                    current_mac = mac
            else:
                switch_back()
                current_mac = None
        time.sleep(POLL_INTERVAL_SEC)


if __name__ == "__main__":
    main()
