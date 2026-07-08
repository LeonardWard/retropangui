#!/usr/bin/env python3
"""RetroPangui share 파티션(exFAT, ROM/세이브/스크린샷 등) 백업/복원 도구.

SD카드를 새로 플래싱하기 전에 share 파티션 내용을 로컬 디렉토리로
백업해두고, 플래싱 후 새 share 파티션에 복원할 때 씀. SD카드 자동
탐색 로직은 scripts/flash-sd.sh의 find_sd_cards()를 그대로 옮김.

사용법:
  python3 scripts/backup-share.py --backup [--source DEVICE] [--dest DIR]
  python3 scripts/backup-share.py --restore --source DIR [--dest DEVICE]

  --backup: SD카드 share 파티션 -> 로컬 디렉토리
    --source: SD카드 장치(예: /dev/sdb). 생략 시 자동 탐색.
    --dest:   백업 저장 디렉토리. 생략 시 ./share-backup-<시각>/

  --restore: 로컬 디렉토리 -> SD카드 share 파티션
    --source: 백업 디렉토리 (필수)
    --dest:   SD카드 장치(예: /dev/sdb). 생략 시 자동 탐색.

인자 없이 실행하면 이 도움말을 출력함.
"""
import argparse
import datetime
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SHARE_PART_SUFFIXES = ("3", "p3")
MIN_SIZE_GB = 1
MAX_SIZE_GB = 512


def run(cmd, **kwargs):
    return subprocess.run(cmd, check=True, **kwargs)


def sh(cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout.strip()


def is_root_disk(devpath: str) -> bool:
    mountpoints = sh(["lsblk", "-no", "MOUNTPOINT", devpath]).splitlines()
    return "/" in [m.strip() for m in mountpoints]


def find_sd_cards() -> list[str]:
    """flash-sd.sh의 find_sd_cards()와 동일한 기준으로 후보 장치를 찾음."""
    candidates = []
    for sys_block in sorted(Path("/sys/block").glob("sd*")) + sorted(
        Path("/sys/block").glob("mmcblk*")
    ):
        name = sys_block.name
        devpath = f"/dev/{name}"
        if not Path(devpath).is_block_device():
            continue
        if is_root_disk(devpath):
            continue

        try:
            size_bytes = int((sys_block / "size").read_text().strip())
        except (OSError, ValueError):
            continue
        size_gb = size_bytes * 512 // (1024**3)
        if not (MIN_SIZE_GB <= size_gb <= MAX_SIZE_GB):
            continue

        removable = (sys_block / "removable").read_text().strip() if (
            sys_block / "removable"
        ).exists() else "0"
        if removable == "1" or name.startswith("mmcblk"):
            candidates.append(devpath)
    return candidates


def pick_device(candidates: list[str], purpose: str) -> str:
    if len(candidates) == 1:
        return candidates[0]
    if not candidates:
        dev = input(f"SD카드를 찾을 수 없습니다. 장치 경로 직접 입력 ({purpose}): ").strip()
        if not Path(dev).is_block_device():
            sys.exit(f"[ERROR] 유효하지 않은 장치입니다: {dev}")
        return dev

    print(f"\nSD카드 후보가 여러 개 발견됐습니다 ({purpose}):")
    for i, dev in enumerate(candidates):
        size = sh(["lsblk", "-dno", "SIZE", dev]) or "?"
        model_path = Path(f"/sys/block/{Path(dev).name}/device/model")
        model = model_path.read_text().strip() if model_path.exists() else "unknown"
        print(f"  {i + 1}) {dev}  {size}  {model}")
    choice = input("\n선택 (번호 입력): ").strip()
    try:
        dev = candidates[int(choice) - 1]
    except (ValueError, IndexError):
        sys.exit("[ERROR] 잘못된 선택입니다.")
    return dev


def find_share_partition(device: str) -> str:
    for suffix in SHARE_PART_SUFFIXES:
        part = f"{device}{suffix}"
        if Path(part).is_block_device():
            return part
    sys.exit(
        f"[ERROR] {device}에서 share 파티션(3번, exFAT)을 찾을 수 없습니다.\n"
        "  SD카드가 이미 RetroPangui 이미지로 플래싱된 상태인지 확인하세요."
    )


def mount_and_run(part: str, action):
    """part를 임시로 마운트하고 mountpoint를 action에 넘겨 실행, 끝나면 항상 언마운트."""
    with tempfile.TemporaryDirectory(prefix="rpui-share-") as mnt:
        already_mounted = sh(["lsblk", "-no", "MOUNTPOINT", part])
        temp_mount = not already_mounted
        if temp_mount:
            run(["sudo", "mount", part, mnt])
            mountpoint = mnt
        else:
            mountpoint = already_mounted
        try:
            action(mountpoint)
        finally:
            if temp_mount:
                run(["sudo", "umount", mountpoint])


def do_backup(source: str | None, dest: str | None):
    device = source or pick_device(find_sd_cards(), "백업 대상")
    part = find_share_partition(device)

    if dest is None:
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        dest = f"./share-backup-{stamp}"
    dest_path = Path(dest).resolve()
    dest_path.mkdir(parents=True, exist_ok=True)

    print(f"백업: {part} -> {dest_path}")

    def action(mountpoint):
        run(
            [
                "sudo",
                "rsync",
                "-a",
                "--info=progress2",
                f"{mountpoint}/",
                f"{dest_path}/",
            ]
        )
        run(["sudo", "chown", "-R", f"{sh(['id', '-un'])}:{sh(['id', '-gn'])}", str(dest_path)])

    mount_and_run(part, action)
    print(f"백업 완료: {dest_path}")


def do_restore(source: str | None, dest: str | None):
    if source is None:
        sys.exit("[ERROR] --restore는 --source(백업 디렉토리)가 필수입니다.")
    src_path = Path(source).resolve()
    if not src_path.is_dir():
        sys.exit(f"[ERROR] 백업 디렉토리를 찾을 수 없습니다: {src_path}")

    device = dest or pick_device(find_sd_cards(), "복원 대상")
    part = find_share_partition(device)

    print(f"복원: {src_path} -> {part}")
    print(f"경고: {part}의 기존 내용 위에 덮어씁니다 (삭제된 파일은 지워지지 않음).")
    confirm = input("계속하려면 'yes' 또는 'y' 입력: ").strip().lower()
    if confirm not in ("yes", "y"):
        sys.exit("취소됐습니다.")

    def action(mountpoint):
        run(["sudo", "rsync", "-a", "--info=progress2", f"{src_path}/", f"{mountpoint}/"])
        run(["sync"])

    mount_and_run(part, action)
    print("복원 완료.")


def main():
    parser = argparse.ArgumentParser(
        description="RetroPangui share 파티션(exFAT) 백업/복원 도구",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--backup", action="store_true", help="SD카드 share -> 로컬 디렉토리")
    mode.add_argument("--restore", action="store_true", help="로컬 디렉토리 -> SD카드 share")
    parser.add_argument("--source", help="백업: SD카드 장치. 복원: 백업 디렉토리(필수)")
    parser.add_argument("--dest", help="백업: 저장 디렉토리. 복원: SD카드 장치")

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(0)

    args = parser.parse_args()

    if not shutil.which("rsync"):
        sys.exit("[ERROR] rsync가 설치되어 있지 않습니다.")

    if args.backup:
        do_backup(args.source, args.dest)
    elif args.restore:
        do_restore(args.source, args.dest)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
