RETROPANGUI_INITRAMFS_VERSION = 0.1
RETROPANGUI_INITRAMFS_SOURCE = busybox-1.36.1.tar.bz2
RETROPANGUI_INITRAMFS_SITE = https://busybox.net/downloads
RETROPANGUI_INITRAMFS_LICENSE = GPL-2.0+
RETROPANGUI_INITRAMFS_LICENSE_FILES = LICENSE
RETROPANGUI_INITRAMFS_INSTALL_IMAGES = YES

RETROPANGUI_INITRAMFS_PKGDIR := $(BR2_EXTERNAL_C5_PANGUI_PATH)/package/retropangui-initramfs

define RETROPANGUI_INITRAMFS_BUILD_CMDS
	cp $(RETROPANGUI_INITRAMFS_PKGDIR)/busybox.config $(@D)/.config
	yes "" | $(MAKE) -C $(@D) ARCH=arm64 CROSS_COMPILE=$(TARGET_CROSS) oldconfig
	$(MAKE) -C $(@D) ARCH=arm64 CROSS_COMPILE=$(TARGET_CROSS) busybox
endef

define RETROPANGUI_INITRAMFS_INSTALL_IMAGES_CMDS
	fakeroot -- sh -c " \
	    rm -rf $(@D)/initramfs_root && \
	    mkdir -p $(@D)/initramfs_root/bin && \
	    mkdir -p $(@D)/initramfs_root/proc $(@D)/initramfs_root/sys $(@D)/initramfs_root/dev && \
	    mkdir -p $(@D)/initramfs_root/tmp && \
	    mkdir -p $(@D)/initramfs_root/boot_root $(@D)/initramfs_root/new_root && \
	    mkdir -p $(@D)/initramfs_root/overlay $(@D)/initramfs_root/merged && \
	    mkdir -p $(@D)/initramfs_root/dbg && \
	    install -m 755 $(@D)/busybox $(@D)/initramfs_root/bin/busybox && \
	    for applet in sh ash mount umount switch_root mkdir mknod ln cat echo sleep printf sha256sum cp mv rm sync mdev awk grep ls tr; do \
	        ln -sf /bin/busybox $(@D)/initramfs_root/bin/\$$applet; \
	    done && \
	    mknod $(@D)/initramfs_root/dev/console c 5 1 && \
	    install -m 755 $(RETROPANGUI_INITRAMFS_PKGDIR)/init $(@D)/initramfs_root/init && \
	    ( cd $(@D)/initramfs_root && find . | cpio -H newc -o | gzip -9 > $(BINARIES_DIR)/initramfs.cpio.gz ) \
	"
	@echo ">>> initramfs.cpio.gz 생성 완료: $(BINARIES_DIR)/initramfs.cpio.gz"
endef

$(eval $(generic-package))
