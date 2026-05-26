```
./Achlys kernel.nox --freestanding
clang -target x86_64-pc-none-elf -ffreestanding -fno-builtin -nostdlib -mno-red-zone -mno-sse -mno-avx -msoft-float -c kernel.ll -o kernel.o
ld -n -T linker.ld boot.o kernel.o -o achlys_os.bin
grub-mkrescue -o achlys_os.iso isodir
qemu-system-x86_64 -cdrom achlys_os.iso -vga std -netdev user,id=n1 -device e1000,netdev=n1 -vnc :0
```
