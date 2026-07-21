#!/bin/bash
# check-core-registration.sh - 코어 등록 일관성 검증 (defconfig ↔ systems.json)
#
# 발단(todo-20260716-core-registration-check.html): defconfig에서 코어를 켜도
# systems.json에 등록하지 않으면 빌드는 100% 성공하는데 ES 코어 선택 메뉴에
# 안 떠서 존재 자체를 모르게 됨(lr-beetle-psx-hw 사고). 반대 방향(systems.json
# 에만 있음)은 게임 실행 시 dlopen 실패로 이어짐. 둘 다 "빌드 성공 = 정상"이란
# 착각을 만드는 조용한 누락이라 빌드 전에 기계적으로 잡는다.
#
# 명명 규칙 의존 제거(2026-07-18 설계 재정비): 심볼명→module_id 즉석 변환 규칙
# 대신 br2-external/package/libretro-core-*/ 디렉토리를 진실 공급원으로 사용 -
#   module_id  = "lr-" + (패키지 디렉토리명에서 "libretro-core-" 제거)
#   BR2 심볼   = 그 패키지 Config.in의 "config BR2_..." 첫 줄
# 이 매핑은 실제 설치 경로(/usr/lib/libretro/<module_id>)와 정의상 일치하므로
# allowlist가 필요 없다.
#
# 2026-07-21(후속 작업 3, Kconfig depends 도입): defconfig 텍스트만 grep하면
# "depends on으로 실제로는 꺼지는 코어인데 defconfig엔 =y가 남아있는" 경우를
# 놓칠 수 있음(todo-20260712-libretro-cores-package-split.html 참고 - 다른
# 기기 defconfig에서는 켜질 수 있는 심볼이라 defconfig 자체에서 지우진 않으므로
# 원천적으로 발생 가능). buildroot/.config(직전 syncconfig의 실제 해석 결과)가
# 있으면 그걸 우선 신뢰 - Kconfig가 depends를 이미 반영해서 만든 최종 진실이라
# 별도 파서 없이 정확함. .config가 없으면(빌드 이력 없는 클린 체크아웃) 기존
# defconfig 텍스트 방식으로 폴백 - 이 경우 후속 빌드의 post-build.sh 2단
# 검사(실제 설치된 .so 기준)가 최종 안전망.
#
# 사용: check-core-registration.sh <repo_root>
# 종료코드: 0=일관, 1=불일치(빌드 중단 권장)

set -u

ROOT="${1:?사용법: check-core-registration.sh <repo_root>}"
DEFCONFIG="${ROOT}/configs/retropangui-odroidc5_defconfig"
RESOLVED_CONFIG="${ROOT}/buildroot/.config"
SYSTEMS_JSON="${ROOT}/board/odroidc5/systems.json"
PKG_DIR="${ROOT}/br2-external/package"

if [ -f "$RESOLVED_CONFIG" ]; then
    CONFIG_SOURCE="$RESOLVED_CONFIG"
    echo "  (참고: 직전 빌드의 buildroot/.config 기준 - Kconfig depends 반영된 실제 값)"
else
    CONFIG_SOURCE="$DEFCONFIG"
fi

FAIL=0

# systems.json의 module_id 전체 목록
JSON_MODIDS=$(python3 - "$SYSTEMS_JSON" <<'PYEOF'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    data = json.load(f)
systems = data if isinstance(data, list) else data.get('systems', data)
mids = sorted({c['module_id'] for s in systems for c in s.get('cores', []) if 'module_id' in c})
print('\n'.join(mids))
PYEOF
)

for pkg in "${PKG_DIR}"/libretro-core-*/; do
    pkg_name=$(basename "$pkg")
    modid="lr-${pkg_name#libretro-core-}"
    symbol=$(grep -m1 -o 'BR2_PACKAGE_LIBRETRO_CORE_[A-Z0-9_]*' "${pkg}/Config.in" 2>/dev/null || true)
    [ -z "$symbol" ] && continue

    if grep -q "^${symbol}=y" "$CONFIG_SOURCE"; then enabled=1; else enabled=0; fi
    if echo "$JSON_MODIDS" | grep -qx "$modid"; then registered=1; else registered=0; fi

    if [ "$enabled" = "1" ] && [ "$registered" = "0" ]; then
        echo "  [ERROR] ${modid}: defconfig에서 빌드되는데 systems.json 미등록 - ES 코어 선택 메뉴에 안 뜸 (beetle-psx-hw 사고 유형)"
        FAIL=1
    elif [ "$enabled" = "0" ] && [ "$registered" = "1" ]; then
        echo "  [ERROR] ${modid}: systems.json에 등록됐는데 defconfig에서 빌드 안 됨 - 게임 실행 시 dlopen 실패 (실체 없는 메뉴)"
        FAIL=1
    fi
done

# systems.json에 있는데 대응 패키지 디렉토리 자체가 없는 module_id (오타 탐지)
while IFS= read -r modid; do
    [ -z "$modid" ] && continue
    pkg_name="libretro-core-${modid#lr-}"
    if [ ! -d "${PKG_DIR}/${pkg_name}" ]; then
        echo "  [ERROR] ${modid}: systems.json에 등록됐는데 br2-external/package/${pkg_name} 패키지가 없음 (오타?)"
        FAIL=1
    fi
done <<< "$JSON_MODIDS"

if [ "$FAIL" = "0" ]; then
    echo "  코어 등록 일관성 OK (defconfig ↔ systems.json)"
fi
exit $FAIL
