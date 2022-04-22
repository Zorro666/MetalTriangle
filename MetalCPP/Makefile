METALCPP_TRIANGLE_OBJS=metalcpp-triangle/main.o

ifdef DEBUG
DBG_OPT_FLAGS=-g
else
DBG_OPT_FLAGS=-O2
endif

ifdef ASAN
ASAN_FLAGS=-fsanitize=address
else
ASAN_FLAGS=
endif

CC=clang++
CFLAGS=-Wall -std=c++17 -I./metal-cpp -I./metal-cpp-extensions -fno-objc-arc $(DBG_OPT_FLAGS) $(ASAN_FLAGS)
LDFLAGS=-framework Metal -framework Foundation -framework Cocoa -framework CoreGraphics -framework MetalKit 

VPATH=./metal-cpp

%.o: %.cpp
	$(CC) -c $(CFLAGS) $< -o $@


all: build/metalcpp-triangle

.PHONY: all

build/metalcpp-triangle: $(METALCPP_TRIANGLE_OBJS) Makefile
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) $(LDFLAGS) $(METALCPP_TRIANGLE_OBJS) -o $@

clean:
	@rm -f $(METALCPP_TRIANGLE_OBJS)
	@rm -rf build
