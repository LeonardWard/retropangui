CC      ?= gcc
CFLAGS  ?= -O2 -Wall -Wextra
TARGET   = storage-mgr

all: $(TARGET)

$(TARGET): storage_mgr.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

clean:
	rm -f $(TARGET)

.PHONY: all clean
