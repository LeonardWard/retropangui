#!/usr/bin/env bash

# 파일명: es_systems_generator.sh
# Retro Pangui Module: ES Systems Configuration Generator
#
# 이 스크립트는 systemlist.csv를 기반으로 es_systems.cfg를 생성하는 함수들을 제공합니다.
# Multi-core 지원을 포함하여 Recalbox 스타일의 시스템 설정을 생성합니다.
# ===============================================

# systemlist.csv를 기반으로 es_systems.xml을 생성하는 함수 (Multi-core 지원)
# ES에서 직접 RetroArch를 실행하고, 여러 코어 중 priority 기반으로 선택
generate_es_systems_xml_multi_core() {
    local src_csv="$1"
    local dest_xml="$2"

    # 필요한 전역 변수 확인
    local roms_path="${USER_ROMS_PATH}"
    local retroarch_path="${RETROARCH_BIN_PATH}"
    local cores_path="${LIBRETRO_CORE_PATH}"
    local config_path="${USER_CONFIG_PATH}/cores"

    if [[ ! -f "$src_csv" ]]; then
        log_msg ERROR "CSV 소스 파일을 찾을 수 없습니다: $src_csv"
        return 1
    fi

    log_msg INFO "es_systems.xml 생성을 시작합니다 (Multi-core 방식)..."
    sudo rm -f "$dest_xml"

    echo '<?xml version="1.0"?>' | sudo tee "$dest_xml" > /dev/null
    echo "<systemList>" | sudo tee -a "$dest_xml" > /dev/null

    # awk로 CSV를 파싱하여 시스템 정보와 모든 코어 정보를 추출
    local parsed_data=$(awk -F, '
        NR==1 {
            # 헤더 행: 컬럼 인덱스 매핑
            for (i=1; i<=NF; i++) {
                gsub(/\r/, "", $i);
                col_map[$i] = i;
                rev_col_map[i] = $i;
            }
            next;
        }
        {
            # 각 행마다 시스템 기본 정보 추출
            name = $(col_map["name"]);
            fullname = $(col_map["fullname"]);
            path = $(col_map["descriptor_1_path"]);
            theme = $(col_map["descriptor_1_theme"]);
            extensions = $(col_map["descriptor_1_extensions"]);

            if (name == "") { next; }

            # 모든 코어 정보를 수집 (libretro 에뮬레이터만)
            cores_info = "";
            for (i=1; i<=NF; i++) {
                header = rev_col_map[i];

                # emulatorList_1_emulator_1_core_N_name 패턴 찾기
                if (header ~ /emulatorList_1_emulator_1_core_[0-9]+_name/ && $i != "") {
                    core_name = $i;

                    # 동일 코어의 priority와 extensions 찾기
                    priority_header = header;
                    gsub("_name", "_priority", priority_header);
                    priority = $(col_map[priority_header]);

                    ext_header = header;
                    gsub("_name", "_extensions", ext_header);
                    core_extensions = $(col_map[ext_header]);

                    # 코어 정보를 구분자로 연결 (이름|우선순위|확장자)
                    if (cores_info != "") cores_info = cores_info "@@";
                    cores_info = cores_info core_name "|" priority "|" core_extensions;
                }
            }

            # 출력: name^fullname^path^theme^extensions^cores_info
            if (cores_info != "") {
                printf "%s^%s^%s^%s^%s^%s\n", name, fullname, path, theme, extensions, cores_info;
            }
        }
    ' "$src_csv")

    # 파싱된 데이터를 한 줄씩 읽어 XML 블록 생성
    echo "$parsed_data" | while IFS='^' read -r name fullname path theme extensions cores_info; do
        if [[ -z "$name" || -z "$cores_info" ]]; then continue; fi

        final_path=$(echo "$path" | sed "s|%ROOT%|$roms_path|")

        # XML 시작
        cat << EOF | sudo tee -a "$dest_xml" > /dev/null
 <system>
    <name>$name</name>
    <fullname>$fullname</fullname>
    <path>$final_path</path>
    <extension>$extensions</extension>
    <cores>
EOF

        # 코어 정보를 파싱하여 <core> 태그 생성
        IFS='@@' read -ra cores_array <<< "$cores_info"
        for core_entry in "${cores_array[@]}"; do
            IFS='|' read -r core_name priority core_ext <<< "$core_entry"

            if [[ -n "$core_name" ]]; then
                cat << EOF | sudo tee -a "$dest_xml" > /dev/null
        <core name="$core_name" priority="$priority" extensions="$core_ext"/>
EOF
            fi
        done

        # XML 종료 (command 템플릿 생성 - ES가 %CORE%, %CONFIG% 변수를 치환)
        cat << EOF | sudo tee -a "$dest_xml" > /dev/null
    </cores>
    <command>$retroarch_path -L %CORE% --config %CONFIG% %ROM%</command>
    <platform>$name</platform>
    <theme>$theme</theme>
 </system>
EOF
    done

    echo "</systemList>" | sudo tee -a "$dest_xml" > /dev/null

    sudo chown "$__user":"$__user" "$dest_xml"
    log_msg SUCCESS "es_systems.xml 생성 완료 (Multi-core 방식): $dest_xml"
}
