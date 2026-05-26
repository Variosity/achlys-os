; boot.asm - Achlys Ignition Sequence & VESA Framebuffer
global _start
extern _achlys_init
extern achlys_panic

section .multiboot
align 4
    dd 0x1BADB002            ; Magic
    dd 0x00000007            ; Flags (Page Align | Mem Info | VIDEO MODE)
    dd - (0x1BADB002 + 0x00000007) ; Checksum
    
    ; REQUIRED PADDING FOR MULTIBOOT SPEC (Offsets 12 to 28)
    dd 0, 0, 0, 0, 0
    
    ; The Video Mode Request (Must be at exactly Offset 32)
    dd 0                     ; Mode type: 0 = linear graphics
    dd 1024                  ; Width
    dd 768                   ; Height
    dd 32                    ; Depth

section .bss
align 4096
p4_table: resb 4096
p3_table: resb 4096
; Allocate four P2 tables to cover 4 Gigabytes of physical RAM
p2_table_0: resb 4096
p2_table_1: resb 4096
p2_table_2: resb 4096
p2_table_3: resb 4096
stack_bottom: resb 16384
stack_top:

align 16
idt: resb 4096 
idt_ptr: resw 1
         resq 1

section .rodata
gdt64:
    dq 0 
.code: equ $ - gdt64
    dq (1<<43) | (1<<44) | (1<<47) | (1<<53) 
.pointer:
    dw $ - gdt64 - 1
    dq gdt64

section .text
bits 32
_start:
    mov esp, stack_top

    ; Extract Framebuffer Info
    mov eax, [ebx]
    bt eax, 12
    jnc .skip_fb
    mov eax, [ebx + 88]
    mov [0x5000], eax
    mov eax, [ebx + 96]
    mov [0x5004], eax
    mov eax, [ebx + 100]
    mov [0x5008], eax
    mov eax, [ebx + 104]
    mov [0x500C], eax
.skip_fb:

    ; [NEW] Extract Multiboot Ramdisk Modules!
    ; ebx + 20 contains the number of files injected
    ; ebx + 24 contains the physical RAM address of the file list
    mov eax, [ebx + 20]
    mov [0x5010], eax
    mov eax, [ebx + 24]
    mov [0x5014], eax

    ; [NEW] Map 4 Gigabytes of RAM
    mov eax, p3_table
    or eax, 0b11 
    mov [p4_table], eax

    ; Link all 4 tables into the hierarchy
    mov eax, p2_table_0
    or eax, 0b11
    mov [p3_table], eax
    mov eax, p2_table_1
    or eax, 0b11
    mov [p3_table + 8], eax
    mov eax, p2_table_2
    or eax, 0b11
    mov [p3_table + 16], eax
    mov eax, p2_table_3
    or eax, 0b11
    mov [p3_table + 24], eax

    ; Loop 2048 times (2048 * 2MB = 4GB of RAM)
    mov ecx, 0
.map_p2_table:
    mov eax, 0x200000 
    mul ecx
    or eax, 0b10000011 
    mov [p2_table_0 + ecx * 8], eax
    inc ecx
    cmp ecx, 2048
    jne .map_p2_table

    ; Enable 64-bit Mode
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax
    mov eax, p4_table
    mov cr3, eax
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    lgdt [gdt64.pointer]
    jmp gdt64.code:long_mode_start

bits 64
long_mode_start:
    mov ax, 0
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; Install IDT
    mov rdi, idt
    mov rcx, 32
    mov rsi, isr_stub_table
.idt_loop:
    mov rax, [rsi]           
    mov [rdi], ax            
    mov word [rdi + 2], 0x08 
    mov word [rdi + 4], 0x8E00 
    shr rax, 16
    mov [rdi + 6], ax        
    shr rax, 16
    mov [rdi + 8], eax       
    mov dword [rdi + 12], 0  
    add rdi, 16
    add rsi, 8
    loop .idt_loop

    mov word [idt_ptr], 4095
    mov rax, idt
    mov [idt_ptr + 2], rax
    lidt [idt_ptr]           

    call _achlys_init
    cli
.hang:
    hlt
    jmp .hang

%macro ISR_STUB 1
isr_stub_%1:
    cli
    mov rdi, %1       
    call achlys_panic 
    hlt
%endmacro

ISR_STUB 0
ISR_STUB 1
ISR_STUB 2
ISR_STUB 3
ISR_STUB 4
ISR_STUB 5
ISR_STUB 6
ISR_STUB 7
ISR_STUB 8
ISR_STUB 9
ISR_STUB 10
ISR_STUB 11
ISR_STUB 12
ISR_STUB 13
ISR_STUB 14
ISR_STUB 15
ISR_STUB 16
ISR_STUB 17
ISR_STUB 18
ISR_STUB 19
ISR_STUB 20
ISR_STUB 21
ISR_STUB 22
ISR_STUB 23
ISR_STUB 24
ISR_STUB 25
ISR_STUB 26
ISR_STUB 27
ISR_STUB 28
ISR_STUB 29
ISR_STUB 30
ISR_STUB 31

align 8
isr_stub_table:
    dq isr_stub_0, isr_stub_1, isr_stub_2, isr_stub_3, isr_stub_4, isr_stub_5, isr_stub_6, isr_stub_7
    dq isr_stub_8, isr_stub_9, isr_stub_10, isr_stub_11, isr_stub_12, isr_stub_13, isr_stub_14, isr_stub_15
    dq isr_stub_16, isr_stub_17, isr_stub_18, isr_stub_19, isr_stub_20, isr_stub_21, isr_stub_22, isr_stub_23
    dq isr_stub_24, isr_stub_25, isr_stub_26, isr_stub_27, isr_stub_28, isr_stub_29, isr_stub_30, isr_stub_31

; ===================================================
; ACHLYS HARDWARE ACCELERATOR
; ===================================================
global fast_memcpy
; void fast_memcpy(dest (rdi), src (rsi), bytes (rdx))
fast_memcpy:
    mov rcx, rdx
    shr rcx, 3      ; Divide by 8
    rep movsq       ; Copy 64-bits (8 bytes) at a time at hardware speed
    mov rcx, rdx
    and rcx, 7      ; Get remainder
    rep movsb       ; Copy remaining bytes
    ret

; void fast_fill32(dest (rdi), color (rsi), pixel_count (rdx))
global fast_fill32
fast_fill32:
    mov rax, rsi    ; Move the 32-bit color into RAX
    mov rcx, rdx    ; Move the pixel count into RCX
    rep stosd       ; Hardware flood-fill!
    ret