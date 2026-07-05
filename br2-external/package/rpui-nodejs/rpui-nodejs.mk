################################################################################
#
# rpui-nodejs
#
# nodejs.org 공식 사전 컴파일 바이너리(linux-arm64)를 그대로 설치.
# AI CLI(Claude Code 등)가 요구하는 최신 Node 버전을 Buildroot 자체
# nodejs 패키지(V8 처음부터 컴파일, 버전 고정)보다 빠르게 확보하기 위함.
#
################################################################################

RPUI_NODEJS_VERSION = 24.18.0
RPUI_NODEJS_SITE = https://nodejs.org/dist/v$(RPUI_NODEJS_VERSION)
RPUI_NODEJS_SOURCE = node-v$(RPUI_NODEJS_VERSION)-linux-arm64.tar.xz
RPUI_NODEJS_LICENSE = MIT
RPUI_NODEJS_LICENSE_FILES = LICENSE

define RPUI_NODEJS_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/opt/nodejs
	cp -a $(@D)/bin $(@D)/lib $(@D)/include $(TARGET_DIR)/opt/nodejs/
	rm -rf $(TARGET_DIR)/opt/nodejs/lib/node_modules/npm/docs
	rm -rf $(TARGET_DIR)/opt/nodejs/lib/node_modules/npm/man
	mkdir -p $(TARGET_DIR)/usr/bin
	ln -sf /opt/nodejs/bin/node $(TARGET_DIR)/usr/bin/node
	ln -sf /opt/nodejs/bin/npm $(TARGET_DIR)/usr/bin/npm
	ln -sf /opt/nodejs/bin/npx $(TARGET_DIR)/usr/bin/npx
	if [ -e $(TARGET_DIR)/opt/nodejs/bin/corepack ]; then \
		ln -sf /opt/nodejs/bin/corepack $(TARGET_DIR)/usr/bin/corepack; \
	fi
endef

$(eval $(generic-package))
