################################################################################
#
# uim
#
################################################################################

UIM_VERSION = 1.9.6
UIM_SITE = https://github.com/uim/uim/releases/download/$(UIM_VERSION)
UIM_LICENSE = BSD-3-Clause
UIM_LICENSE_FILES = COPYING
UIM_DEPENDENCIES = ncurses gettext host-pkgconf

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

$(eval $(autotools-package))
