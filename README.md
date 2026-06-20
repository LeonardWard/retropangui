# RetroPangUI

Odroid C5 (Amlogic S905X5M)용 레트로 게이밍 OS.

Buildroot 기반, EmulationStation + RetroArch + Kodi.

> 상세 문서는 [Wiki](../../wiki)를 참고하세요.

---

## 빌드 요구사항

- Docker 26.0 이상
- RAM 8GB 이상, 디스크 여유 50GB 이상
- 첫 빌드 약 2~4시간

## 빠른 시작

```bash
# 전체 빌드
./build.sh

# OTA squashfs만 생성
./build.sh --ota

# 부분 빌드 (ES/gamepad-mgr 수정 후)
./build.sh --partial
```

버전은 `git tag`에서 자동 감지됩니다. 태그를 만들고 빌드하면 해당 버전으로 이미지가 생성됩니다.

## 플래싱

```bash
bash scripts/flash-sd.sh                              # 자동 탐지
bash scripts/flash-sd.sh output/retropangui-*.img     # 직접 지정
```

## 접속

| 방법 | 주소 |
|------|------|
| SSH | `ssh root@retropangui-c5.lan` |
| SFTP | `sftp://root@retropangui-c5.lan` |
| 기본 비밀번호 | `odroid` |

## OTA 업데이트

```bash
# OTA 빌드
./build.sh --ota

# 로컬 파일서버에 배포
bash scripts/push-ota.sh output/retropangui-odroidc5-<version>.squashfs

# 파일서버 실행
bash scripts/serve-ota.sh
```

## 릴리즈 노트

[GitHub Releases](../../releases) 또는 `git tag -l`로 확인.
각 태그 어노테이션에 해당 버전 변경 내역이 포함되어 있습니다.
