CC      ?= gcc
CFLAGS  ?= -O2 -Wall -Wextra
TARGET   = rpui-bt

all: $(TARGET)

$(TARGET): rpui_bt.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

clean:
	rm -f $(TARGET)

.PHONY: all clean
