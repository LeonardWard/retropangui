# U-Boot boot script for RetroPangUI on Odroid C5
# Ubuntu 실제 boot.scr 주소 기준으로 작성

# U-Boot 기본 환경 변수 사용 (Ubuntu 호환)
if test -z "${loadaddr_kernel}"; then setenv loadaddr_kernel 0x03000000; fi
if test -z "${dtb_mem_addr}";    then setenv dtb_mem_addr 0x01000000;   fi
setenv ramdisk_addr_r 0x30000000

setenv bootargs "console=tty1 console=ttyS0,115200n8 earlycon=aml_uart,0xfe07a000 net.ifnames=0 vout=1920x1080p60hz,enable connector0_type=HDMI-A-A hdmimode=1920x1080p60hz hdmitx=,422,12bit panic=0"

load mmc ${devnum}:1 ${loadaddr_kernel} Image
load mmc ${devnum}:1 ${dtb_mem_addr} s7d_s905x5m_odroidc5.dtb
load mmc ${devnum}:1 ${ramdisk_addr_r} initramfs.cpio.gz
booti ${loadaddr_kernel} ${ramdisk_addr_r}:${filesize} ${dtb_mem_addr}
