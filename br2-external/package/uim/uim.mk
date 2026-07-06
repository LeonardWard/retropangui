################################################################################
#
# uim
#
################################################################################

UIM_VERSION = 1.9.6
UIM_SITE = https://github.com/uim/uim/releases/download/$(UIM_VERSION)
UIM_LICENSE = BSD-3-Clause
UIM_LICENSE_FILES = COPYING
UIM_DEPENDENCIES = ncurses gettext host-pkgconf host-uim

# 2026-07-07: uim 빌드 중 scm/installed-modules.scm을 생성하는 단계가 방금 막
# 빌드한 uim-module-manager 실행파일을 직접 실행해서 결과를 만들어냄(Scheme
# 인터프리터로 각 입력기 모듈을 실제로 로드해봐야 하는 구조라 정적으로 미리
# 만들어둘 수 없음) - 크로스 컴파일이라 그 실행파일이 aarch64용이라 빌드
# 호스트(x86_64)에서 실행이 안 돼 "Exec format error"로 실패함(Buildroot의
# guile 패키지가 guild 컴파일 단계에서 겪는 것과 동일한 문제 - guile.mk의
# HOST_GUILE + GUILE_FOR_BUILD 패턴을 그대로 따름). host-uim으로 네이티브
# x86_64용 uim-module-manager를 별도로 빌드해서 그걸 대신 쓰게 함.
UIM_BUILDDIR = $(BUILD_DIR)/uim-$(UIM_VERSION)
UIM_MAKE_OPTS = \
	UIM_MODULE_MANAGER=$(HOST_DIR)/bin/uim-module-manager \
	UIM_MODULE_MANAGER_ENV="LIBUIM_SYSTEM_SCM_FILES=$(UIM_BUILDDIR)/sigscheme/lib LIBUIM_SCM_FILES=$(UIM_BUILDDIR)/scm LIBUIM_PLUGIN_LIB_DIR=$(HOST_DIR)/lib/uim/plugin UIM_DISABLE_NOTIFY=1"

# 2026-07-07: uim이 내장한 sigscheme의 libgcroots가 공유 라이브러리(.so)로
# 빌드되는데, 이건 시스템에 install되는 게 아니라 uim 빌드 트리 안에만 있는
# 내부 전용 라이브러리 - libuim-scm.so를 링크할 땐 알아서 -rpath로 이 경로를
# 찾지만, 정작 그 libuim-scm.so에 의존하는 최종 실행파일들(uim-sh, uim-agent,
# uim-help, uim-module-manager)을 링크할 땐 이 경로가 안 넘어가서
# "undefined reference to GCROOTS_*" 링크 에러가 남 - -rpath-link로 빌드
# 디렉토리를 직접 지정해서 해결.
UIM_CONF_ENV = LDFLAGS="$(TARGET_LDFLAGS) -Wl,-rpath-link,$(BUILD_DIR)/uim-$(UIM_VERSION)/sigscheme/libgcroots/.libs"

# 2026-07-06: GTK/Qt(각 버전)/일본어(anthy/canna/wnn/prime/sj3)/curl/sqlite3/
# libffi/m17nlib 등은 전부 끄고, 텍스트 터미널 전용 프론트엔드(uim-fep)와
# 한글 입력 엔진(벼루, byeoru.scm)만 남김 - GUI 없는 fbterm 콘솔 환경이라
# 이 의존성들은 전부 불필요(byeoru는 Scheme 스크립트라 별도 빌드 옵션 없이
# uim 코어에 항상 포함됨).
UIM_CONF_OPTS = \
	--without-gtk2 \
	--without-gtk3 \
	--without-qt \
	--without-qt-immodule \
	--without-qt4 \
	--without-qt4-immodule \
	--without-qt5 \
	--without-qt5-immodule \
	--without-qt6 \
	--without-qt6-immodule \
	--without-anthy \
	--without-anthy-utf8 \
	--without-canna \
	--without-wnn \
	--without-mana \
	--without-prime \
	--without-sj3 \
	--without-skk \
	--without-m17nlib \
	--without-curl \
	--without-sqlite3 \
	--without-ffi \
	--without-eb \
	--without-libedit \
	--disable-gnome-applet \
	--disable-gnome3-applet \
	--disable-kde-applet \
	--disable-kde4-applet \
	--disable-emacs \
	--disable-dict \
	--disable-notify \
	--enable-fep

HOST_UIM_DEPENDENCIES = host-ncurses host-gettext host-pkgconf
HOST_UIM_CONF_OPTS = $(UIM_CONF_OPTS)

$(eval $(autotools-package))
$(eval $(host-autotools-package))
