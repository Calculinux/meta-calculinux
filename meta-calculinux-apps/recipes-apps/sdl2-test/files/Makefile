TARGETS = sdl2-test sdl2-list-backends
SRCS = sdl2-test.c sdl2-list-backends.c

all: $(TARGETS)

sdl2-test: sdl2-test.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $< $(LDLIBS)

sdl2-list-backends: sdl2-list-backends.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $< $(LDLIBS)

clean:
	rm -f $(TARGETS)

.PHONY: all clean
