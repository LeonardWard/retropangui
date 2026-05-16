CC      ?= gcc
CFLAGS  ?= -O2 -Wall -Wextra
# SDL2_CFLAGS / SDL2_LIBS는 호스트 빌드 시 pkg-config, 크로스빌드 시 .mk에서 주입
SDL2_CFLAGS ?= $(shell pkg-config --cflags sdl2 2>/dev/null)
SDL2_LIBS   ?= $(shell pkg-config --libs   sdl2 2>/dev/null) -lm
CFLAGS  += $(SDL2_CFLAGS) -I.
LDFLAGS += $(SDL2_LIBS)

LIB_SRCS = gamepad.c gamepad_slot.c gamepad_mapping.c
LIB_OBJS = $(LIB_SRCS:.c=.o)

.PHONY: all clean install

all: libgamepad.a gamepad-test gamepad-daemon

libgamepad.a: $(LIB_OBJS)
	$(AR) rcs $@ $^

gamepad-test: gamepad_test.o libgamepad.a
	$(CC) -o $@ $^ $(LDFLAGS)

gamepad-daemon: gamepad_vdev.o gamepad_daemon.o libgamepad.a
	$(CC) -o $@ $^ $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

install: libgamepad.a gamepad-daemon
	install -D -m 644 libgamepad.a      $(DESTDIR)/usr/lib/libgamepad.a
	install -D -m 644 gamepad.h         $(DESTDIR)/usr/include/gamepad.h
	install -D -m 644 gamepad_slot.h    $(DESTDIR)/usr/include/gamepad_slot.h
	install -D -m 644 gamepad_mapping.h $(DESTDIR)/usr/include/gamepad_mapping.h
	install -D -m 755 gamepad-daemon    $(DESTDIR)/usr/bin/gamepad-daemon

clean:
	rm -f *.o libgamepad.a gamepad-test gamepad-daemon
