#!/bin/bash
# detect-stale-package-caches.sh - git 커밋 비교로 로컬 소스/Kconfig 옵션이
# 바뀐 패키지만 정확히 찾아서 buildroot 빌드 캐시를 지운다.
#
# 배경(2026-07-20): Buildroot는 이미 빌드된 패키지의 로컬 소스나 Kconfig
# 옵션이 바뀌어도 자동으로 재빌드하지 않는 알려진 한계가 있음. 이 프로젝트는
# 지금까지 이 문제를 겪을 때마다 "해당 패키지 캐시를 매 빌드마다 무조건
# 강제 삭제"하는 식으로 땜질해왔는데(커널, mali-ddk, retropangui-initramfs,
# bundled-bgmusic, alsa-utils, freeimage 등), 실제로 변경이 없을 때도 매번
# 비용이 발생해서 빌드 시간이 누적으로 늘어나는 원인이었음
# (todo-20260720-build-force-clean-audit.html 참고).
#
# 이 스크립트는 "마지막으로 성공한 빌드 시점의 소스 상태"와 "지금 워킹트리"를
# git diff로 비교해서, 실제로 바뀐 파일에 해당하는 패키지의 output/build/ 캐시만
# 지운다. 기준점은 build.sh가 빌드 성공 직후 기록하는데, 커밋 안 한 수정까지
# 포함하기 위해 HEAD가 아니라 stash 임시 커밋(git stash create)일 수 있음 -
# git diff <커밋>은 stash 커밋에도 똑같이 동작하므로 여기선 구분할 필요 없다.
#
# 사용법: scripts/detect-stale-package-caches.sh [DEVICE]
# (반드시 저장소 루트에서 실행 — build.sh가 여기서 호출함)

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${SCRIPT_DIR}"

DEVICE="${1:-odroidc5}"
STATE_FILE="buildroot/output/.last_built_commit"
BUILD_DIR="buildroot/output/build"

if [ ! -d "${BUILD_DIR}" ]; then
    echo "[stale-cache] ${BUILD_DIR} 없음 - 첫 빌드로 판단, 감지 스킵"
    exit 0
fi

if [ ! -f "${STATE_FILE}" ]; then
    echo "[stale-cache] 이전 빌드 커밋 기록 없음 - 이번 빌드부터 추적 시작(강제 삭제 없음)"
    exit 0
fi

PREV_COMMIT="$(cat "${STATE_FILE}")"
if ! git cat-file -e "${PREV_COMMIT}" 2>/dev/null; then
    echo "[stale-cache] 이전 커밋(${PREV_COMMIT})을 git 히스토리에서 못 찾음 - 감지 스킵"
    exit 0
fi

# 워킹트리 기준으로 비교(커밋 안 한 로컬 수정도 잡기 위함 - git diff <commit>은
# 두 번째 ref를 안 주면 워킹트리와 비교함)
CHANGED_FILES="$(git diff --name-only "${PREV_COMMIT}" -- . 2>/dev/null || true)"

if [ -z "${CHANGED_FILES}" ]; then
    echo "[stale-cache] ${PREV_COMMIT} 이후 변경된 파일 없음"
    exit 0
fi

echo "[stale-cache] ${PREV_COMMIT} 이후 변경 파일:"
echo "${CHANGED_FILES}" | sed 's/^/  /'

# 실제 패키지 디렉토리가 있는지 이름을 뒤에서부터 한 세그먼트씩 떼어내며 확인
# (예: BLUEZ5_UTILS_TOOLS -> bluez5_utils_tools(없음) -> bluez5_utils(있음))
find_package_dir() {
    local base="$1"
    while [ -n "${base}" ]; do
        for candidate in "${base}" "${base//_/-}"; do
            if [ -d "buildroot/package/${candidate}" ]; then
                echo "${candidate}"; return 0
            fi
            if [ -d "br2-external/package/${candidate}" ]; then
                echo "${candidate}"; return 0
            fi
        done
        case "${base}" in
            *_*) base="${base%_*}" ;;
            *)   base="" ;;
        esac
    done
    return 1
}

TO_CLEAR=()
REFETCH_BLOBS=0
REFETCH_FONTS=0

while IFS= read -r f; do
    [ -z "$f" ] && continue

    case "$f" in
        board/${DEVICE}/patches/linux/*)
            TO_CLEAR+=("linux-custom")
            ;;
        board/${DEVICE}/fetch-blobs.sh)
            REFETCH_BLOBS=1
            TO_CLEAR+=("mali-ddk")        # 블롭 소비 패키지도 같이 재빌드
            ;;
        board/${DEVICE}/fetch-fonts.sh)
            REFETCH_FONTS=1
            TO_CLEAR+=("bundled-fonts")   # 폰트 소비 패키지도 같이 재빌드
            ;;
        board/${DEVICE}/rootfs-overlay/*)
            # rootfs-overlay는 매 빌드 rootfs 조립 때 자동 반영 - 패키지 캐시와 무관
            ;;
        board/*)
            # 패키지 .mk가 board/ 밑의 소스를 직접 참조하는 경우(예: rpui-launcher가
            # board/odroidc5/rpui-launcher.py를 install). br2-external/package/ 밖에
            # 소스가 있으면 위 경로 규칙에 안 걸리는 사각지대가 있었음(2026-07-20,
            # launcher 수정이 빌드에 반영 안 된 실사례). basename 참조 검색이라
            # 과잉 매칭 가능성이 있지만 방향이 "추가 재빌드"라 안전.
            hits=$(grep -l -F "$(basename "$f")" br2-external/package/*/*.mk 2>/dev/null || true)
            for mk in $hits; do
                pkg="${mk#br2-external/package/}"
                pkg="${pkg%%/*}"
                echo "  board 소스 '$f' -> 패키지 '${pkg}' (.mk 참조 매칭)"
                TO_CLEAR+=("${pkg}")
            done
            ;;
        br2-external/package/*/*)
            pkg="${f#br2-external/package/}"
            pkg="${pkg%%/*}"
            TO_CLEAR+=("${pkg}")
            ;;
        br2-external/package/libretro-core-organizer.mk)
            # 2026-07-20/21 후속 작업 1·2(_VERSION/_SITE/_PLATFORM 중앙화): 이 파일은
            # br2-external/package/<pkg>/ 하위가 아니라 패키지 디렉토리 바로 위에
            # 있어서 위 br2-external/package/*/* 규칙에 안 걸리는 사각지대 -
            # 착수 전에 미리 문서에 기록해둔 주의사항(todo-20260712-libretro-cores-
            # package-split.html). 바뀐 <PREFIX>_VERSION/_SITE/_PLATFORM 라인만 추출해
            # 해당 코어 패키지로 매핑(defconfig 처리와 동일 패턴, find_package_dir 재사용).
            while IFS= read -r prefix; do
                [ -z "$prefix" ] && continue
                base="$(echo "${prefix}" | tr 'A-Z' 'a-z')"
                pkgdir="$(find_package_dir "${base}")" || true
                if [ -n "${pkgdir}" ]; then
                    echo "  libretro-core-organizer.mk: ${prefix}_* 변경 -> 패키지 '${pkgdir}'로 매칭"
                    TO_CLEAR+=("${pkgdir}")
                else
                    echo "  libretro-core-organizer.mk: ${prefix}_* 변경했지만 대응 패키지 디렉토리를 못 찾음 - 수동 확인 필요"
                fi
            done < <(git diff "${PREV_COMMIT}" -- "$f" 2>/dev/null | grep -oE '^[+-][A-Z0-9_]+_(VERSION|SITE|PLATFORM)' | sed -E 's/^[+-]//; s/_(VERSION|SITE|PLATFORM)$//' | sort -u)
            ;;
        configs/retropangui-${DEVICE}_defconfig)
            # 라인 단위로 diff해서 바뀐 BR2_PACKAGE_* 심볼만 추출
            while IFS= read -r sym; do
                [ -z "$sym" ] && continue
                base="$(echo "${sym#BR2_PACKAGE_}" | tr 'A-Z' 'a-z')"
                pkgdir="$(find_package_dir "${base}")" || true
                if [ -n "${pkgdir}" ]; then
                    echo "  defconfig: ${sym} 변경 -> 패키지 '${pkgdir}'로 매칭"
                    TO_CLEAR+=("${pkgdir}")
                else
                    echo "  defconfig: ${sym} 변경했지만 대응 패키지 디렉토리를 못 찾음 - 수동 확인 필요"
                fi
            done < <(git diff "${PREV_COMMIT}" -- "$f" 2>/dev/null | grep -oE '^[+-]BR2_PACKAGE_[A-Z0-9_]+' | tr -d '+-' | sort -u)
            ;;
    esac
done <<< "${CHANGED_FILES}"

# fetch 스크립트 자체가 바뀌면(버전 올림, URL 교체 등) "파일 있으니 스킵"에
# 걸려 낡은 다운로드를 계속 쓰게 되므로, 지우고 그 자리에서 바로 다시 받는다.
# (build.sh의 fetch 단계는 이 스크립트보다 먼저 돌기 때문에 여기서 직접 재실행)
if [ "${REFETCH_BLOBS}" -eq 1 ]; then
    echo "[stale-cache] fetch-blobs.sh 변경 감지 - Mali 블롭 삭제 후 재다운로드"
    rm -rf "board/${DEVICE}/blobs/mali"
    bash "board/${DEVICE}/fetch-blobs.sh"
fi
if [ "${REFETCH_FONTS}" -eq 1 ]; then
    echo "[stale-cache] fetch-fonts.sh 변경 감지 - 번들 폰트 삭제 후 재다운로드"
    rm -rf "board/${DEVICE}/blobs/fonts"
    bash "board/${DEVICE}/fetch-fonts.sh"
fi

if [ ${#TO_CLEAR[@]} -eq 0 ]; then
    echo "[stale-cache] 캐시 정리 대상 패키지 없음"
    exit 0
fi

# 중복 제거 후 실제 삭제
printf '%s\n' "${TO_CLEAR[@]}" | sort -u | while IFS= read -r pkg; do
    matched=$(ls -d "${BUILD_DIR}/${pkg}"* 2>/dev/null || true)
    if [ -n "${matched}" ]; then
        echo "[stale-cache] 삭제: ${matched}"
        rm -rf ${matched}
    else
        echo "[stale-cache] '${pkg}' 캐시가 없음(아직 한 번도 안 빌드됐거나 이미 정리됨) - 스킵"
    fi
done
