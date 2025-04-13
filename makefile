# HARDN makefile

# Compiler
CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2
SRC_DIR = src
BUILD_DIR = build
BIN_DIR = bin

TARGET = $(BIN_DIR)/hardn
SRCS = $(wildcard $(SRC_DIR)/*.c)
OBJS = $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.o, $(SRCS))

all: $(TARGET)

$(TARGET): $(OBJS)
    @mkdir -p $(BIN_DIR)
    $(CC) $(CFLAGS) -o $@ $^

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
    @mkdir -p $(BUILD_DIR)
    $(CC) $(CFLAGS) -c $< -o $@

install: $(TARGET)
    @mkdir -p $(DESTDIR)/usr/bin
    cp $(TARGET) $(DESTDIR)/usr/bin/

clean:
    rm -rf $(BUILD_DIR) $(BIN_DIR)

.PHONY: all clean install