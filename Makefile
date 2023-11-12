.PHONY: all clean

all: server.s
	mkdir target
	as --gstabs -o target/server.o server.s && ld -o target/server target/server.o 

clean:
	rm -rf target
