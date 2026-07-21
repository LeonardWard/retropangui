#!/bin/sh
# apply_retropangui_conf.sh - retropangui.conf 설정을 각 컴포넌트에 적용
#
# 적용 규칙:
#   global.*         → /retropangui/share/system/retroarch/retroarch.cfg
#   emulationstation.* → /root/.emulationstation/es_settings.cfg
#   system.*         → OS 수준 설정 (hostname, timezone 등)
#
# 사용법: apply_retropangui_conf.sh [conf_file]
# 기본 conf_file: /retropangui/share/system/retropangui.conf

CONF_FILE="${1:-/retropangui/share/system/retropangui.conf}"
RETROARCH_CFG="/retropangui/share/system/retroarch/retroarch.cfg"
ES_SETTINGS_CFG="/retropangui/share/system/emulationstation/es_settings.cfg"

if [ ! -f "${CONF_FILE}" ]; then
    echo "[retropangui] 설정 파일 없음: ${CONF_FILE}"
    exit 1
fi

echo "[retropangui] 설정 적용 중: ${CONF_FILE}"

# -------------------------------------------------------------------
# 유틸리티 함수
# -------------------------------------------------------------------

# retroarch.cfg 에서 특정 키를 업데이트하거나 추가
# 사용법: ra_set KEY VALUE
ra_set() {
    local key="$1"
    local val="$2"
    if grep -q "^${key} *=" "${RETROARCH_CFG}" 2>/dev/null; then
        sed -i "s|^${key} *=.*|${key} = \"${val}\"|" "${RETROARCH_CFG}"
    else
        echo "${key} = \"${val}\"" >> "${RETROARCH_CFG}"
    fi
}

# true/false 값은 따옴표 없이 저장 (RetroArch 규칙)
ra_set_bool() {
    local key="$1"
    local val="$2"
    if grep -q "^${key} *=" "${RETROARCH_CFG}" 2>/dev/null; then
        sed -i "s|^${key} *=.*|${key} = ${val}|" "${RETROARCH_CFG}"
    else
        echo "${key} = ${val}" >> "${RETROARCH_CFG}"
    fi
}

# es_settings.cfg 에 XML 항목 업데이트하거나 추가
# ES 설정 파일 형식 (pugixml): <?xml ...?><config><string name="Key" value="Val" /></config>
# 사용법: es_set TYPE KEY VALUE
es_set() {
    local type="$1"   # string, bool, int, float
    local key="$2"
    local val="$3"
    # POSIX/busybox 셸의 "\t"는 이스케이프되지 않고 백슬래시+t 두 글자 그대로
    # 남는다(실기기 hex dump로 확인, 2026-07-19) - printf로 진짜 탭 문자를 만든다.
    local tab
    tab="$(printf '\t')"
    local line="${tab}<${type} name=\"${key}\" value=\"${val}\" />"

    # 파일 없거나 XML 골격 없으면 새로 생성
    if [ ! -f "${ES_SETTINGS_CFG}" ] || ! grep -q "<config" "${ES_SETTINGS_CFG}" 2>/dev/null; then
        printf '<?xml version="1.0"?>\n<config>\n%s\n</config>\n' "${line}" > "${ES_SETTINGS_CFG}"
        return
    fi

    if grep -q "name=\"${key}\"" "${ES_SETTINGS_CFG}" 2>/dev/null; then
        sed -i "s|.*name=\"${key}\".*|${line}|" "${ES_SETTINGS_CFG}"
    else
        # </config> 바로 앞에 삽입
        sed -i "s|</config>|${line}\n</config>|" "${ES_SETTINGS_CFG}"
    fi
}

# -------------------------------------------------------------------
# retropangui.conf 파싱 및 적용
# -------------------------------------------------------------------

while IFS='=' read -r raw_key raw_val; do
    # 주석(#) 및 빈 줄 건너뜀
    case "${raw_key}" in
        '#'*|'') continue ;;
    esac

    key="$(echo "${raw_key}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    val="$(echo "${raw_val}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    # 빈 키 건너뜀
    [ -z "${key}" ] && continue

    # ---------------------------------------------------------------
    # global.* → retroarch.cfg
    # ---------------------------------------------------------------
    case "${key}" in
        global.*)
            ra_key="${key#global.}"
            case "${val}" in
                true|false)
                    ra_set_bool "${ra_key}" "${val}" ;;
                *)
                    ra_set "${ra_key}" "${val}" ;;
            esac
            ;;

        # ---------------------------------------------------------------
        # emulationstation.Language → es_settings.cfg + OS 로케일 + RA 언어
        # (아래 emulationstation.* 범용 분기보다 먼저 와야 함 - case문은
        # 처음 매칭된 패턴만 실행하므로, 이 특수 케이스가 범용 와일드카드를
        # 가로챔. 2026-07-21: 예전엔 이 값이 system.language였는데,
        # apply_retropangui_conf.sh 자체가 "최초 부팅/키 병합 시에만" 또는
        # ES 설정 메뉴 저장 이벤트로만 실행되는 스크립트라, 그 사이에 ES가
        # 먼저 뜨면 es_settings.cfg가 stale해서 영어로 뜨는 레이스가 있었음
        # (사용자가 2번 겪음). emulationstation.* 이름으로 바꿔서 ES 자신이
        # Settings::loadRetropanguiConf()로 매 시작마다 직접 읽게 해 이
        # 레이스를 근본적으로 없앰 - 이 스크립트의 es_set 호출은 그대로 두되
        # (es_settings.cfg도 계속 동기화해서 일관성 유지), OS 로케일/RA 언어
        # 부수효과는 여기서 계속 처리.
        # ---------------------------------------------------------------
        emulationstation.Language)
            echo "LANG=${val}.UTF-8" > /etc/locale.conf
            es_set "string" "Language" "${val}"
            case "${val}" in
                ko*) ra_lang=10 ;;
                ja*) ra_lang=1  ;;
                fr*) ra_lang=2  ;;
                es*) ra_lang=3  ;;
                de*) ra_lang=4  ;;
                it*) ra_lang=5  ;;
                nl*) ra_lang=6  ;;
                pt_BR*) ra_lang=7 ;;
                pt*) ra_lang=8  ;;
                ru*) ra_lang=9  ;;
                zh_TW*|zh_HK*) ra_lang=11 ;;
                zh*) ra_lang=12 ;;
                pl*) ra_lang=14 ;;
                tr*) ra_lang=18 ;;
                uk*) ra_lang=26 ;;
                *)   ra_lang=0  ;;
            esac
            ra_set "user_language" "${ra_lang}"
            ;;

        # ---------------------------------------------------------------
        # emulationstation.* → es_settings.cfg
        # ---------------------------------------------------------------
        emulationstation.*)
            es_key="${key#emulationstation.}"
            case "${val}" in
                true|false)
                    es_set "bool" "${es_key}" "${val}" ;;
                [0-9]*)
                    # ScreenSaverTime: retropangui.conf는 초 단위, ES는 ms 단위
                    if [ "${es_key}" = "ScreenSaverTime" ]; then
                        val="$((val * 1000))"
                    fi
                    es_set "int" "${es_key}" "${val}" ;;
                *)
                    es_set "string" "${es_key}" "${val}" ;;
            esac
            ;;

        # ---------------------------------------------------------------
        # system.* → OS 설정
        # ---------------------------------------------------------------
        system.hostname)
            echo "${val}" > /etc/hostname
            hostname "${val}"
            ;;
        system.timezone)
            if [ -f "/usr/share/zoneinfo/${val}" ]; then
                ln -sfn "/usr/share/zoneinfo/${val}" /etc/localtime
                echo "${val}" > /etc/timezone
            else
                echo "[retropangui] 알 수 없는 시간대: ${val}"
            fi
            ;;
        system.ssh)
            case "${val}" in
                1|yes|true)
                    [ -f /etc/init.d/S50sshd ] && /etc/init.d/S50sshd start 2>/dev/null ;;
                0|no|false)
                    [ -f /etc/init.d/S50sshd ] && /etc/init.d/S50sshd stop 2>/dev/null ;;
            esac
            ;;
        system.samba)
            case "${val}" in
                1|yes|true)
                    [ -f /etc/init.d/S91ksmbd ] && /etc/init.d/S91ksmbd start 2>/dev/null ;;
                0|no|false)
                    [ -f /etc/init.d/S91ksmbd ] && /etc/init.d/S91ksmbd stop 2>/dev/null ;;
            esac
            ;;
        # system.bundlegame_show: 2026-07-12부로 GuiMenu.cpp의
        # openGameSettings()가 rpui-bundlegame show/hide 호출 + quitES()
        # 순서까지 네이티브로 직접 처리함(killall 부작용 제거 겸 레이스
        # 방지) - 여기선 더 이상 손 안 대고 system.* 캐치올로 흘려보냄.
        system.wifi.enabled)
            case "${val}" in
                1|yes|true)
                    command -v rpui-wifi >/dev/null 2>&1 && rpui-wifi start 2>/dev/null ;;
                0|no|false)
                    command -v rpui-wifi >/dev/null 2>&1 && rpui-wifi disable 2>/dev/null ;;
            esac
            ;;
        system.volume)
            amixer -q sset 'Master' "${val}%" 2>/dev/null || true
            ;;
        system.*)
            # 미처리 system.* 항목은 무시
            ;;
    esac
done < "${CONF_FILE}"

echo "[retropangui] 설정 적용 완료"
