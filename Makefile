CC        ?= gcc
CFLAGS    ?= -Wall -Wextra -O2
SRC_DIR   = src
BUILD_DIR = build
BIN_DIR   = bin
TARGET    = $(BIN_DIR)/hardn

RUST_TARGET = target/release/hardn

SRCS = $(wildcard $(SRC_DIR)/*.c)
OBJS = $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.o, $(SRCS))

prefix    ?= /usr/local
bindir     = $(prefix)/bin

all: build-c build-rust

build-c: $(TARGET)

$(TARGET): $(OBJS)
	@mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $^

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

build-rust:
	cargo build --release

install: $(TARGET) build-rust
	@mkdir -p $(DESTDIR)$(bindir)
	install -m 755 $(TARGET) $(DESTDIR)$(bindir)/hardn-c
	install -m 755 $(RUST_TARGET) $(DESTDIR)$(bindir)/hardn

uninstall:
	rm -f $(DESTDIR)$(bindir)/hardn
	rm -f $(DESTDIR)$(bindir)/hardn-c

clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR) target

.PHONY: all build-c build-rust clean install uninstall