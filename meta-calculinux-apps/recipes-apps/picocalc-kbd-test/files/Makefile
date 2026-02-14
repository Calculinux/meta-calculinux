TARGET = picocalc-kbd-test

all: $(TARGET)

$(TARGET): picocalc-kbd-test.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS) $(LDLIBS)

clean:
	rm -f $(TARGET)

.PHONY: all clean
