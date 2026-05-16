setenv loadaddr "0x03080000"
setenv dtb_loadaddr "0x01000000"
setenv bootargs "console=tty1 console=ttyS0,115200n8 earlycon=aml_uart,0xfe07a000 root=/dev/mmcblk${devnum}p2 rootwait rw fsck.repair=yes net.ifnames=0 vout=1920x1080p60hz,enable connector0_type=HDMI-A-A hdmimode=1920x1080p60hz hdmitx=,422,12bit"

load mmc ${devnum}:1 ${loadaddr} Image
load mmc ${devnum}:1 ${dtb_loadaddr} s7d_s905x5m_odroidc5.dtb
booti ${loadaddr} - ${dtb_loadaddr}
