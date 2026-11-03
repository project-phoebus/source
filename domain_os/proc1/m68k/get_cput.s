|
| proc1/m68k/get_cput.s - PROC1_$GET_CPUT, PROC1_$GET_CPUT8,
| PROC1_$GET_CPU_USAGE and their helper proc1_$get_current_cpu_time
|
| The SAU2, SAU3 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the
| image's encodings, every address operand a relocation resolved against
| the image's.
|
| SAU2 map: in "D E1EAC8 PROC1_ASM size = 24A4", 0xE20894..0xE208F6:
|   0xE20894  PROC1_$GET_CPUT       (clock: out, the CPU time doubled:
|                                    D1:D0 shifted left once as 48 bits)
|   0xE2089C  PROC1_$GET_CPUT8      (clock: out, the CPU time as read);
|                                    falls into the shared store 0xE2089E
|   0xE208AA  PROC1_$GET_CPU_USAGE  (clock: out, doubled; stat1, stat2:
|                                    out, the PCB's +0x60 and +0x64,
|                                    re-read after the helper returns)
|   0xE208D0  (no symbol)           proc1_$get_current_cpu_time: under
|                                    a saved and raised SR, D1 =
|                                    cpu_total (+1 on the carry), D0.w =
|                                    cpu_usage + vtimer -
|                                    TIME_$VT_TIMER()
| PROC1_$INT_ADVANCE (0xE208F6) follows, proc1/m68k/int_handler.s.
|
        .section ".text.PROC1_$GET_CPUT","ax",@progbits
        .balign 2

        .globl  PROC1_$GET_CPUT
        .globl  PROC1_$GET_CPUT8
        .globl  PROC1_$GET_CPU_USAGE

        .extern PROC1_$CURRENT_PCB              | proc1/m68k/proc1_data.s
        .extern TIME_$VT_TIMER                  | time/m68k/time_asm.s

PROC1_$GET_CPUT:
        bsr.s   proc1_$get_current_cpu_time     | e20894  613a
        lsl.w   #1,%d0                          | e20896  e348
        roxl.l  #1,%d1                          | e20898  e391
        bra.s   .Le2089e                        | e2089a  6002
PROC1_$GET_CPUT8:
        bsr.s   proc1_$get_current_cpu_time     | e2089c  6132
.Le2089e:
        movea.l (0x4,%sp),%a0                   | e2089e  206f 0004
        move.l  %d1,(%a0)                       | e208a2  2081
        move.w  %d0,(0x4,%a0)                   | e208a4  3140 0004
        rts                                     | e208a8  4e75
PROC1_$GET_CPU_USAGE:
        bsr.s   proc1_$get_current_cpu_time     | e208aa  6124
        lsl.w   #1,%d0                          | e208ac  e348
        roxl.l  #1,%d1                          | e208ae  e391
        movea.l (0x4,%sp),%a0                   | e208b0  206f 0004
        move.l  %d1,(%a0)                       | e208b4  2081
        move.w  %d0,(0x4,%a0)                   | e208b6  3140 0004
        movea.l (PROC1_$CURRENT_PCB:w,%pc),%a1  | e208ba  227a e20c
        movea.l (0x8,%sp),%a0                   | e208be  206f 0008
        move.l  (0x60,%a1),(%a0)                | e208c2  20a9 0060
        movea.l (0xc,%sp),%a0                   | e208c6  206f 000c
        move.l  (0x64,%a1),(%a0)                | e208ca  20a9 0064
        rts                                     | e208ce  4e75
proc1_$get_current_cpu_time:
        move.w  %sr,-(%sp)                      | e208d0  40e7
        ori.w   #0x700,%sr                      | e208d2  007c 0700
        jsr     TIME_$VT_TIMER                  | e208d6  4eb9 00e2 af6c
        movea.l (PROC1_$CURRENT_PCB:w,%pc),%a1  | e208dc  227a e1ea
        neg.w   %d0                             | e208e0  4440
        add.w   (0x48,%a1),%d0                  | e208e2  d069 0048
        move.l  (0x4c,%a1),%d1                  | e208e6  2229 004c
        add.w   (0x50,%a1),%d0                  | e208ea  d069 0050
        bcc.s   .Le208f2                        | e208ee  6402
        addq.l  #1,%d1                          | e208f0  5281
.Le208f2:
        move.w  (%sp)+,%sr                      | e208f2  46df
        rts                                     | e208f4  4e75
