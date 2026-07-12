# U-Boot boot script for RetroPangUI on Odroid C5
# Ubuntu 실제 boot.scr 주소 기준으로 작성

# 2026-07-12: vout=/hdmimode= bootargs 제거 - 커널 소스(vout_serve.c)를 직접
# 확인한 결과 이 두 값은 죽은 파라미터임(__setup 등록이 실제로는 안 걸리거나
# 파싱 코드 자체가 없음, dmesg의 "Unknown kernel command line parameters"로
# 실측 확인). 진짜 부팅 시점 해상도 제어는 U-Boot 바이너리 자체가
# board_late_init()에서 이 스크립트보다 먼저 자동으로 읽는 config.ini
# (board/odroidc5/config.ini, [generic] 섹션의 displaymode=)가 담당함 -
# 자세한 내용은 todo-20260709-resolution-design.html 참고.

# U-Boot 기본 환경 변수 사용 (Ubuntu 호환)
if test -z "${loadaddr_kernel}"; then setenv loadaddr_kernel 0x03000000; fi
if test -z "${dtb_mem_addr}";    then setenv dtb_mem_addr 0x01000000;   fi
setenv ramdisk_addr_r 0x30000000

setenv bootargs "console=tty1 console=ttyS0,115200n8 earlycon=aml_uart,0xfe07a000 net.ifnames=0 connector0_type=HDMI-A-A hdmitx=,422,12bit panic=1"

load mmc ${devnum}:1 ${loadaddr_kernel} Image
load mmc ${devnum}:1 ${dtb_mem_addr} s7d_s905x5m_odroidc5.dtb
load mmc ${devnum}:1 ${ramdisk_addr_r} initramfs.cpio.gz
booti ${loadaddr_kernel} ${ramdisk_addr_r}:${filesize} ${dtb_mem_addr}
