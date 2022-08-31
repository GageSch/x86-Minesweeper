NAME=final

all: final

clean:
	rm -rf final final.o

final: final.asm
	nasm -f elf -F dwarf -g final.asm
	gcc -no-pie -g -m32 -nostartfiles -z noexecstack -o final final.o
