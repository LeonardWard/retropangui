# RetroPangui Samba 설정 및 Windows 11 접근 가이드

이 문서는 RetroPangui 장치에 Samba 서버를 설정하고, Windows 11에서 공유 폴더에 접근하는 방법을 안내합니다.

## 1. Samba 설정 변경 (스크립트 실행)

`install_base_5_in_5_setup_env.sh` 스크립트는 Samba 서버를 설치하고 `share`, `roms`, `bios`, `saves` 폴더를 공유하도록 설정합니다. 이 스크립트는 인증을 필수로 하도록 구성되어 있습니다.

## 2. Linux 시스템 사용자 생성

Samba에 사용자를 추가하기 전에, 해당 사용자가 RetroPangui 장치의 Linux 시스템에 존재해야 합니다. Windows에서 사용할 사용자 이름(`xein2` 등)과 동일한 이름으로 Linux 시스템 사용자를 생성합니다.

```bash
sudo adduser <사용자이름>
# 예시: sudo adduser xein2
```
명령 실행 시 해당 Linux 사용자의 비밀번호를 설정합니다.

## 3. Samba 사용자 추가 및 비밀번호 설정

Linux 시스템 사용자 생성이 완료되면, 해당 사용자를 Samba 비밀번호 데이터베이스에 추가하고 비밀번호를 설정합니다.

```bash
sudo smbpasswd -a <사용자이름>
# 예시: sudo smbpasswd -a xein2
```

**비밀번호 설정 시 중요 사항:**

*   **Windows Microsoft 온라인 계정 비밀번호 사용**: Windows 11에서 Microsoft 온라인 계정으로 로그인하는 경우, 로컬 계정의 실제 비밀번호는 Microsoft 온라인 계정의 비밀번호와 동일합니다. Samba 비밀번호를 이 Microsoft 온라인 계정 비밀번호와 동일하게 설정하면 Windows에서 가장 편리하게 접근할 수 있습니다.
*   **Windows 비밀번호를 모를 경우**:
    *   **Microsoft 계정 비밀번호 재설정**: Microsoft 계정의 비밀번호를 재설정하여 새로운 비밀번호를 Samba 비밀번호로 사용합니다.
    *   **Samba 전용 비밀번호 설정**: Microsoft 계정 비밀번호를 변경하고 싶지 않다면, Samba에만 사용할 별도의 비밀번호를 설정합니다. 이 경우 Windows에서 공유 폴더에 접근할 때 Samba 사용자 이름과 이 Samba 전용 비밀번호를 수동으로 입력해야 합니다.
*   **PIN은 사용 불가**: Windows 로그인 시 사용하는 PIN은 네트워크 공유 접근 시 사용할 수 없습니다. 반드시 계정의 실제 비밀번호를 사용해야 합니다.

## 4. Windows 11에서 공유 폴더 접근

Windows 11은 보안 정책상 인증되지 않은 게스트 접근을 기본적으로 차단합니다. 따라서 공유 폴더에 접근할 때 사용자 이름과 비밀번호를 제공해야 합니다.

1.  **파일 탐색기 열기**: `Win + E` 키를 누릅니다.
2.  **네트워크 경로 입력**: 파일 탐색기 주소 표시줄에 다음 형식으로 입력합니다.
    *   `\\<RetroPangui 장치의 IP 주소 또는 호스트 이름>\share`
    *   예시: `\\192.168.1.100\share` 또는 `\\retropangui\share`
3.  **자격 증명 입력**: 사용자 이름(`xein2`)과 Samba에 설정한 비밀번호를 입력합니다.

이 가이드를 통해 Samba 설정 및 접근에 도움이 되기를 바랍니다.
