CC      ?= gcc
CFLAGS  ?= -O2 -Wall -Wextra
TARGET   = rpui-wifi

all: $(TARGET)

$(TARGET): rpui_wifi.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

clean:
	rm -f $(TARGET)

.PHONY: all clean
