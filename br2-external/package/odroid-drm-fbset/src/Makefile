CC      ?= gcc
CFLAGS  ?= -O2 -Wall
LDFLAGS ?= -ldrm

all: odroid-drm-fbset

odroid-drm-fbset: odroid-drm-fbset.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f odroid-drm-fbset
