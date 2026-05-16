################################################################################
#
# freeimage
#
################################################################################

FREEIMAGE_VERSION = 3180
FREEIMAGE_SOURCE = FreeImage$(FREEIMAGE_VERSION).zip
FREEIMAGE_SITE = https://downloads.sourceforge.net/project/freeimage/Source%20Distribution/3.18.0
FREEIMAGE_LICENSE = GPL-2.0 or FIPL-1.0
FREEIMAGE_LICENSE_FILES = license-gplv2.txt license-fipl.txt
FREEIMAGE_INSTALL_STAGING = YES
# FreeImage zip extracts to FreeImage/ subdirectory — override default extraction
define FREEIMAGE_EXTRACT_CMDS
	unzip -q $(DL_DIR)/freeimage/$(FREEIMAGE_SOURCE) -d $(@D)-tmp
	cp -r $(@D)-tmp/FreeImage/. $(@D)/
	rm -rf $(@D)-tmp
endef

# FreeImage uses its own Makefile (not autoconf/cmake)
define FREEIMAGE_BUILD_CMDS
	sed -i 's|CXXFLAGS ?=\(.*\)|CXXFLAGS ?=\1 -std=c++14|' $(@D)/Makefile.gnu
	sed -i 's|CFLAGS += -DOPJ_STATIC|CFLAGS += -DOPJ_STATIC -DPNG_ARM_NEON_OPT=0|' $(@D)/Makefile.gnu
	$(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" \
		CXX="$(TARGET_CXX)" \
		AR="$(TARGET_AR)" \
		LDFLAGS="$(TARGET_LDFLAGS)"
endef

FREEIMAGE_SO = libfreeimage-3.18.0.so

FREEIMAGE_INSTALL_STAGING_CMDS = \
	$(INSTALL) -D -m 0755 $(@D)/Dist/$(FREEIMAGE_SO) \
		$(STAGING_DIR)/usr/lib/$(FREEIMAGE_SO) && \
	ln -sf $(FREEIMAGE_SO) $(STAGING_DIR)/usr/lib/libfreeimage.so.3 && \
	ln -sf libfreeimage.so.3 $(STAGING_DIR)/usr/lib/libfreeimage.so && \
	$(INSTALL) -D -m 0644 $(@D)/Dist/FreeImage.h \
		$(STAGING_DIR)/usr/include/FreeImage.h

FREEIMAGE_INSTALL_TARGET_CMDS = \
	$(INSTALL) -D -m 0755 $(@D)/Dist/$(FREEIMAGE_SO) \
		$(TARGET_DIR)/usr/lib/$(FREEIMAGE_SO) && \
	ln -sf $(FREEIMAGE_SO) $(TARGET_DIR)/usr/lib/libfreeimage.so.3 && \
	ln -sf libfreeimage.so.3 $(TARGET_DIR)/usr/lib/libfreeimage.so

$(eval $(generic-package))
