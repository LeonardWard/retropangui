CC         ?= gcc
CFLAGS     ?= -O2 -Wall -Wextra
PKG_CONFIG ?= pkg-config
TARGET      = rpui-bt

GLIB_CFLAGS := $(shell $(PKG_CONFIG) --cflags gio-2.0 gio-unix-2.0)
GLIB_LIBS   := $(shell $(PKG_CONFIG) --libs gio-2.0 gio-unix-2.0)

all: $(TARGET)

$(TARGET): rpui_bt.c
	$(CC) $(CFLAGS) $(GLIB_CFLAGS) $(LDFLAGS) -o $@ $< $(GLIB_LIBS)

clean:
	rm -f $(TARGET)

.PHONY: all clean
