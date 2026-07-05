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
    local line="\t<${type} name=\"${key}\" value=\"${val}\" />"

    # 파일 없거나 XML 골격 없으면 새로 생성
    if [ ! -f "${ES_SETTINGS_CFG}" ] || ! grep -q "<config" "${ES_SETTINGS_CFG}" 2>/dev/null; then
        printf '<?xml version="1.0"?>\n<config>\n%s\n</config>\n' "${line}" > "${ES_SETTINGS_CFG}"
        return
    fi

    if grep -q "name=\"${key}\"" "${ES_SETTINGS_CFG}" 2>/dev/null; then
        sed -i "s|.*name=\"${key}\".*|\t<${type} name=\"${key}\" value=\"${val}\" />|" "${ES_SETTINGS_CFG}"
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
        system.language)
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
        system.bundlegame_show)
            # rpui-bundlegame show/hide는 gamelist.xml을 반영시키려고 매번
            # emulationstation을 killall 함(의도된 동작 — 원래는 사용자가
            # 명시적으로 버튼 눌렀을 때만 호출됐음). 이 항목을 토글로 바꾸면서
            # 값이 안 바뀌어도 메뉴 저장마다 이 스크립트 전체가 재실행되니,
            # 매번 killall이 실행돼 메뉴 진입/퇴장만으로 ES가 죽는 버그가 됨
            # (2026-07-05 발견) — 실제로 상태가 다를 때만 호출하도록 수정.
            if command -v rpui-bundlegame >/dev/null 2>&1; then
                bg_status="$(rpui-bundlegame status 2>/dev/null)"
                bg_hidden="$(echo "${bg_status}" | sed -n 's/.*숨김: \([0-9]*\)개.*/\1/p')"
                case "${val}" in
                    1|yes|true)
                        [ -n "${bg_hidden}" ] && [ "${bg_hidden}" != "0" ] && rpui-bundlegame show 2>/dev/null ;;
                    0|no|false)
                        [ -n "${bg_hidden}" ] && [ "${bg_hidden}" = "0" ] && rpui-bundlegame hide 2>/dev/null ;;
                esac
            fi
            ;;
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
