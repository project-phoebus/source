|
| stop/m68k/watch.s - the stopwatch module, the whole of the hand-written
| STOP_WATCH segment: STOP_$WATCH, its register-argument helpers, the two
| trap handlers, and the module's data after the code
|
| The SAU2 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the image's
| encodings and bytes, every address operand a relocation resolved
| against the image's.
|
| One section for the whole segment.  Every (d,A5) and (d,PC) operand is
| the image's own: A5 = STOP_$WATCH (`lea (STOP_$WATCH,PC),A5',
| 0xE8181C), and the data follows the code in this section as in the
| image, so the displacements are the image's.
|
| SAU2 map: "D E81814 STOP_WATCH size = 914" (.DATA), 0xE81814..0xE82128;
| map symbols STOP_$WATCH, STOP_$WATCH_UII and STOP_$WATCH_TRACE.  One
| section, because STOP_$WATCH's code runs on both sides of
| STOP_$MEASURE_LOOP / STOP_$NULL_PROC and `bsr.b's into the helpers, and
| gas cannot emit a byte branch to another section this far into one.
|
|   0xE81814  STOP_$WATCH          (op, slot, parent, addr, value, status:
|                                   all by address) the SVC entry (TRAP #5
|                                   table, svc/m68k/svc_tables.s): a LINK
|                                   frame, a FIM_$CLEANUP handler; op > 1
|                                   reads (2,4,6) or writes (3,5,7) a byte,
|                                   word or longword at *addr (writes only
|                                   with DISK_$DIAG set, else status
|                                   0x00300004); op <= 1 wires the module
|                                   once (MST_$WIRE_AREA over wire_start..
|                                   wire_end), calibrates once
|                                   (STOP_$MEASURE_LOOP unhooked and hooked
|                                   on STOP_$NULL_PROC), then op 1 hooks
|                                   and op 0 reads and clears a slot (slot
|                                   > 15: 0x00300001; already running:
|                                   0x00300002)
|   0xE81916  STOP_$MEASURE_LOOP   (no symbol) falls into STOP_$NULL_PROC
|   0xE8193E  STOP_$NULL_PROC      (no symbol) a bare `rts'
|   0xE81940                       STOP_$WATCH continued
|   0xE819E2  STOP_$UNHOOK         (no symbol) A1 = slot
|   0xE81A0A  STOP_$HOOK           (no symbol) A0 = patch record, A1 =
|                                   slot, A2 = parent slot or 0, D0.w =
|                                   slot number
|   0xE81A56  STOP_$WATCH_UII      the A-line vector, ends in `rte'
|   0xE81AB2  STOP_$WATCH_TRACE    the second-stage trace handler, `rte'
|   0xE81B54  STOP_$READ_CPUT      (no symbol) result in D1
|   0xE81B5C  STOP_$READ_CLOCK     (no symbol) result in D1
|   0xE81B72  stop_$watch_trace_exit  (no symbol) the exit-trap arm of
|                                   STOP_$WATCH_TRACE
|   0xE81BEA                       an unreached `rts'
|   0xE81BEC  the data, A5+0x3D8 .. A5+0x914 (the labels are its field
|   names):
|             +0x3D8 saved_regs (7 longwords), +0x3F4 sw_overhead,
|             +0x3F8 calibration, +0x3FC trap_counts (65 longwords, one per
|             pid), +0x500 calib_patch {STOP_$NULL_PROC, 0}, +0x508
|             wire_start = STOP_$WATCH, +0x50C wire_end =
|             OS_DATA_SHUTWIRED (0xE82128, the layout's mark at the end of
|             this segment), +0x510 wired (word), +0x512 wire_count (word,
|             4), +0x514 slots (16 * 0x40); zero elsewhere
|
| tools/asm_compare.py LOCAL_SYMBOLS has the image addresses of the names
| without a map symbol.
|
| How the stopwatch works: STOP_$HOOK writes an A-line trap word over the
| instruction at the "entry" address (0xA000 + slot number) and, when there
| is one, over the "exit" address (0xA100 + slot number), saving the
| original words in the slot.  Executing a patched instruction traps to
| STOP_$WATCH_UII, which restores the real instruction word in place,
| stashes the registers, and arms STOP_$WATCH_TRACE_FLAG
| (stop/m68k/watch_trace_flag.s) so the trap is re-taken into
| STOP_$WATCH_TRACE.  The trace handler charges PROC1_$GET_CPUT and
| TIME_$CLOCK deltas to the slot and puts the trap word back.
|
| Slot field offsets:
|   0x00 patch1  0x04 patch2  0x08 parent  0x0C saved1  0x0E saved2
|   0x10 flags (bit 7 running, 6 has an exit patch, 5 in an interval)
|   0x12 owner   0x14 completions   0x18 reentries   0x1C cpu_time
|   0x20 elapsed_time  0x24 cpu_events  0x28 elapsed_events
|   0x2C entry_cput  0x30 entry_clock  0x34 entry_traps  0x38 entry_gtraps
|
        .section ".text.STOP_$WATCH","ax",@progbits
        .balign 2

        .globl  STOP_$WATCH
        .globl  STOP_$MEASURE_LOOP
        .globl  STOP_$NULL_PROC
        .globl  STOP_$UNHOOK
        .globl  STOP_$HOOK
        .globl  STOP_$WATCH_UII
        .globl  STOP_$WATCH_TRACE
        .globl  STOP_$READ_CPUT
        .globl  STOP_$READ_CLOCK
        .globl  stop_$watch_trace_exit

        .extern FIM_$CLEANUP                    | fim/m68k/cleanup.s
        .extern FIM_$RLS_CLEANUP                | fim/m68k/rls_cleanup.s
        .extern DISK_$DIAG                      | disk (Pascal)
        .extern MST_$WIRE_AREA                  | mst/wire_area.pas
        .extern CACHE_$CLEAR                    | cache/m68k/clear.s
        .extern STOP_$WATCH_TRACE_FLAG          | stop/m68k/watch_trace_flag.s
        .extern PROC1_$CURRENT                  | proc1/m68k/proc1_data.s
        .extern PROC1_$GET_CPUT                 | proc1/m68k/get_cput.s
        .extern TIME_$CLOCK                     | time/m68k/time_asm.s
        .extern OS_DATA_SHUTWIRED               | the layout's mark (gen_layout_ld.py)

STOP_$WATCH:
        link.w  %fp,#-20                        | e81814  4e56 ffec
        movem.l %d2-%d7/%a2-%a5,-(%sp)          | e81818  48e7 3f3c
        lea     (STOP_$WATCH:w,%pc),%a5         | e8181c  4bfa fff6
        pea     (-0x14,%fp)                     | e81820  486e ffec
        jsr     FIM_$CLEANUP                    | e81824  4eb9 00e2 1634
        addq.l  #4,%sp                          | e8182a  588f
        move.l  %d0,%d2                         | e8182c  2400
        .short  0xb4bc; .long 0x00120035        | e8182e  b4bc 0012 0035  cmp.l   #0x120035,%d2, the <ea>=#imm form
        bne.w   .Le81968                        | e81834  6600 0132
        movea.l (0x8,%fp),%a0                   | e81838  206e 0008
        move.w  (%a0),%d3                       | e8183c  3610
        .short  0xb67c; .short 0x0001           | e8183e  b67c 0001  cmp.w   #1,%d3, the <ea>=#imm form
        ble.s   .Le8189c                        | e81842  6f58
        movea.l (0x14,%fp),%a0                  | e81844  206e 0014
        movea.l (%a0),%a1                       | e81848  2250
        movea.l (0x18,%fp),%a0                  | e8184a  206e 0018
        move.l  (%a0),%d1                       | e8184e  2210
        clr.l   %d2                             | e81850  4282
        add.w   %d3,%d3                         | e81852  d643
.Le81854:
        jmp     (.Le81854:b,%pc,%d3.w)          | e81854  4efb 30fe
        bra.s   .Le8187e                        | e81858  6024
        bra.s   .Le81882                        | e8185a  6026
        bra.s   .Le81888                        | e8185c  602a
        bra.s   .Le8188c                        | e8185e  602c
        bra.s   .Le81892                        | e81860  6030
        bsr.w   .Le8186a                        | e81862  6100 0006
        move.l  %d1,(%a1)                       | e81866  2281
        bra.s   .Le81896                        | e81868  602c
.Le8186a:
        tst.b   (DISK_$DIAG).l                  | e8186a  4a39 00e7 acca
        bne.s   .Le8187c                        | e81870  660a
        addq.l  #4,%sp                          | e81872  588f
        move.l  #0x300004,%d2                   | e81874  243c 0030 0004
        bra.s   .Le81898                        | e8187a  601c
.Le8187c:
        rts                                     | e8187c  4e75
.Le8187e:
        move.b  (%a1),%d2                       | e8187e  1411
        bra.s   .Le81894                        | e81880  6012
.Le81882:
        bsr.s   .Le8186a                        | e81882  61e6
        move.b  %d1,(%a1)                       | e81884  1281
        bra.s   .Le81896                        | e81886  600e
.Le81888:
        move.w  (%a1),%d2                       | e81888  3411
        bra.s   .Le81894                        | e8188a  6008
.Le8188c:
        bsr.s   .Le8186a                        | e8188c  61dc
        move.w  %d1,(%a1)                       | e8188e  3281
        bra.s   .Le81896                        | e81890  6004
.Le81892:
        move.l  (%a1),%d2                       | e81892  2411
.Le81894:
        move.l  %d2,(%a0)                       | e81894  2082
.Le81896:
        clr.l   %d2                             | e81896  4282
.Le81898:
        bra.w   .Le8195c                        | e81898  6000 00c2
.Le8189c:
        tst.w   (0x510,%a5)                     | e8189c  4a6d 0510
        bne.s   .Le818c4                        | e818a0  6622
        suba.w  #0x10,%sp                       | e818a2  9efc 0010
        movea.l %sp,%a0                         | e818a6  204f
        pea     (.Lwired:w,%pc)                 | e818a8  487a 047a
        pea     (.Lwire_count:w,%pc)            | e818ac  487a 0478
        move.l  %a0,-(%sp)                      | e818b0  2f08
        pea     (.Lwire_end:w,%pc)              | e818b2  487a 046c
        pea     (.Lwire_start:w,%pc)            | e818b6  487a 0464
        jsr     MST_$WIRE_AREA                  | e818ba  4eb9 00e4 4ba4
        adda.w  #0x24,%sp                       | e818c0  defc 0024
.Le818c4:
        tst.l   (0x3f8,%a5)                     | e818c4  4aad 03f8
        bne.s   .Le81902                        | e818c8  6638
        move.l  %d3,-(%sp)                      | e818ca  2f03
        bsr.s   STOP_$MEASURE_LOOP              | e818cc  6148
        move.l  %d1,%d3                         | e818ce  2601
        lea     (.Lcalib_patch:w,%pc),%a0       | e818d0  41fa 0442
        lea     (.Lslots:w,%pc),%a1             | e818d4  43fa 0452
        movea.l #0,%a2                          | e818d8  247c 0000 0000
        moveq   #0,%d0                          | e818de  7000
        bsr.w   STOP_$HOOK                      | e818e0  6100 0128
        bsr.s   STOP_$MEASURE_LOOP              | e818e4  6130
        sub.l   %d3,%d1                         | e818e6  9283
        divu.w  #0x800,%d1                      | e818e8  82fc 0800
        move.w  %d1,(0x3fa,%a5)                 | e818ec  3b41 03fa
        move.l  (0x1c,%a1),%d1                  | e818f0  2229 001c
        divu.w  #0x400,%d1                      | e818f4  82fc 0400
        move.w  %d1,(0x3f6,%a5)                 | e818f8  3b41 03f6
        bsr.w   STOP_$UNHOOK                    | e818fc  6100 00e4
        move.l  (%sp)+,%d3                      | e81900  261f
.Le81902:
        movea.l (0xc,%fp),%a0                   | e81902  206e 000c
        move.w  (%a0),%d0                       | e81906  3010
        .short  0xb07c; .short 0x000f           | e81908  b07c 000f  cmp.w   #0xf,%d0, the <ea>=#imm form
        bls.s   .Le81940                        | e8190c  6332
.Le8190e:
        move.l  #0x300001,%d2                   | e8190e  243c 0030 0001
        bra.s   .Le8195c                        | e81914  6046
STOP_$MEASURE_LOOP:
        ori.w   #0x700,%sr                      | e81916  007c 0700
        bsr.w   STOP_$READ_CPUT                 | e8191a  6100 0238
        move.l  %d1,-(%sp)                      | e8191e  2f01
        move.l  #0x3ff,%d2                      | e81920  243c 0000 03ff
.Le81926:
        bsr.w   STOP_$NULL_PROC                 | e81926  6100 0016
        jsr     CACHE_$CLEAR                    | e8192a  4eb9 00e2 42d4
        dbf     %d2,.Le81926                    | e81930  51ca fff4
        bsr.w   STOP_$READ_CPUT                 | e81934  6100 021e
        sub.l   (%sp)+,%d1                      | e81938  929f
        andi.w  #0xF8FF,%sr                     | e8193a  027c f8ff
STOP_$NULL_PROC:
        rts                                     | e8193e  4e75
.Le81940:
        move.w  %d0,%d1                         | e81940  3200
        lsl.w   #6,%d1                          | e81942  ed49
        lea     (.Lslots:w,%pc),%a1             | e81944  43fa 03e2
        adda.w  %d1,%a1                         | e81948  d2c1
        tst.w   %d3                             | e8194a  4a43
        ble.s   .Le81998                        | e8194c  6f4a
        btst    #7,(0x10,%a1)                   | e8194e  0829 0007 0010
        beq.s   .Le81978                        | e81954  6722
        move.l  #0x300002,%d2                   | e81956  243c 0030 0002
.Le8195c:
        pea     (-0x14,%fp)                     | e8195c  486e ffec
        jsr     FIM_$RLS_CLEANUP                | e81960  4eb9 00e2 165c
        addq.l  #4,%sp                          | e81966  588f
.Le81968:
        movea.l (0x1c,%fp),%a0                  | e81968  206e 001c
        move.l  %d2,(%a0)                       | e8196c  2082
        movem.l (-0x3c,%fp),%d2-%d7/%a2-%a5     | e8196e  4cee 3cfc ffc4
        unlk    %fp                             | e81974  4e5e
        rts                                     | e81976  4e75
.Le81978:
        movea.l (0x14,%fp),%a0                  | e81978  206e 0014
        movea.l #0,%a2                          | e8197c  247c 0000 0000
        movea.l (0x10,%fp),%a3                  | e81982  266e 0010
        move.w  (%a3),%d1                       | e81986  3213
        blt.s   .Le81992                        | e81988  6d08
        lsl.w   #6,%d1                          | e8198a  ed49
        lea     (.Lslots:w,%pc),%a2             | e8198c  45fa 039a
        adda.w  %d1,%a2                         | e81990  d4c1
.Le81992:
        bsr.s   STOP_$HOOK                      | e81992  6176
.Le81994:
        clr.l   %d2                             | e81994  4282
        bra.s   .Le8195c                        | e81996  60c4
.Le81998:
        btst    #7,(0x10,%a1)                   | e81998  0829 0007 0010
        beq.w   .Le8190e                        | e8199e  6700 ff6e
        move.w  %sr,%d2                         | e819a2  40c2
        ori.w   #0x700,%sr                      | e819a4  007c 0700
        move.l  (.Lcalibration:w,%pc),%d0       | e819a8  203a 0262
        move.l  %d0,%d1                         | e819ac  2200
        mulu.w  (0x26,%a1),%d0                  | e819ae  c0e9 0026
        clr.l   (0x24,%a1)                      | e819b2  42a9 0024
        sub.l   %d0,(0x1c,%a1)                  | e819b6  91a9 001c
        mulu.w  (0x2a,%a1),%d1                  | e819ba  c2e9 002a
        clr.l   (0x28,%a1)                      | e819be  42a9 0028
        sub.l   %d1,(0x20,%a1)                  | e819c2  93a9 0020
        movea.l (0x18,%fp),%a3                  | e819c6  266e 0018
        lea     (0x14,%a1),%a2                  | e819ca  45e9 0014
        moveq   #3,%d1                          | e819ce  7203
.Le819d0:
        move.l  (%a2),(%a3)+                    | e819d0  26d2
        clr.l   (%a2)+                          | e819d2  429a
        dbf     %d1,.Le819d0                    | e819d4  51c9 fffa
        move.w  %d2,%sr                         | e819d8  46c2
        tst.w   %d3                             | e819da  4a43
        beq.s   .Le81994                        | e819dc  67b6
        bsr.s   STOP_$UNHOOK                    | e819de  6102
        bra.s   .Le81994                        | e819e0  60b2
STOP_$UNHOOK:
        move.w  %sr,%d1                         | e819e2  40c1
        ori.w   #0x700,%sr                      | e819e4  007c 0700
        movea.l (%a1),%a0                       | e819e8  2051
        move.w  (0xc,%a1),(%a0)                 | e819ea  30a9 000c
        move.l  (0x4,%a1),%d0                   | e819ee  2029 0004
        beq.s   .Le819fa                        | e819f2  6706
        movea.l %d0,%a0                         | e819f4  2040
        move.w  (0xe,%a1),(%a0)                 | e819f6  30a9 000e
.Le819fa:
        jsr     CACHE_$CLEAR                    | e819fa  4eb9 00e2 42d4
        bclr    #7,(0x10,%a1)                   | e81a00  08a9 0007 0010
        move.w  %d1,%sr                         | e81a06  46c1
        rts                                     | e81a08  4e75
STOP_$HOOK:
        moveq   #0xf,%d1                        | e81a0a  720f
        movea.l %a1,%a4                         | e81a0c  2849
.Le81a0e:
        clr.l   (%a4)+                          | e81a0e  429c
        dbf     %d1,.Le81a0e                    | e81a10  51c9 fffc
        move.l  %a2,(0x8,%a1)                   | e81a14  234a 0008
        movem.l (%a0),%a3-%a4                   | e81a18  4cd0 1800
        move.w  %sr,%d1                         | e81a1c  40c1
        ori.w   #0x700,%sr                      | e81a1e  007c 0700
        move.l  %a3,(%a1)                       | e81a22  228b
        move.w  (%a3),(0xc,%a1)                 | e81a24  3353 000c
        move.w  #0xA000,%d2                     | e81a28  343c a000
        add.w   %d0,%d2                         | e81a2c  d440
        move.w  %d2,(%a3)                       | e81a2e  3682
        move.l  %a4,(0x4,%a1)                   | e81a30  234c 0004
        beq.s   .Le81a46                        | e81a34  6710
        bset    #6,(0x10,%a1)                   | e81a36  08e9 0006 0010
        move.w  (%a4),(0xe,%a1)                 | e81a3c  3354 000e
        bset    #8,%d2                          | e81a40  08c2 0008
        move.w  %d2,(%a4)                       | e81a44  3882
.Le81a46:
        bset    #7,(0x10,%a1)                   | e81a46  08e9 0007 0010
        jsr     CACHE_$CLEAR                    | e81a4c  4eb9 00e2 42d4
        move.w  %d1,%sr                         | e81a52  46c1
        rts                                     | e81a54  4e75
STOP_$WATCH_UII:
        ori.w   #0x700,%sr                      | e81a56  007c 0700
        movem.l %d0-%d2/%a0-%a3,-(%sp)          | e81a5a  48e7 e0f0
        movea.l (0x1e,%sp),%a0                  | e81a5e  206f 001e
        move.w  (%a0),%d1                       | e81a62  3210
        clr.w   %d0                             | e81a64  4240
        move.b  %d1,%d0                         | e81a66  1001
        lsl.w   #6,%d0                          | e81a68  ed48
        lea     (.Lslots:w,%pc),%a1             | e81a6a  43fa 02bc
        adda.w  %d0,%a1                         | e81a6e  d2c0
        movea.l (0x24,%sp),%a3                  | e81a70  266f 0024
        btst    #8,%d1                          | e81a74  0801 0008
        bne.s   .Le81a80                        | e81a78  6606
        move.w  (0xc,%a1),(%a0)                 | e81a7a  30a9 000c
        bra.s   .Le81a84                        | e81a7e  6004
.Le81a80:
        move.w  (0xe,%a1),(%a0)                 | e81a80  30a9 000e
.Le81a84:
        lea     (STOP_$WATCH:w,%pc),%a2         | e81a84  45fa fd8e
        movem.l %d0/%a0,-(%sp)                  | e81a88  48e7 8080
        jsr     CACHE_$CLEAR                    | e81a8c  4eb9 00e2 42d4
        movem.l (%sp)+,%d0/%a0                  | e81a92  4cdf 0101
        move.b  (0x1c,%sp),%d0                  | e81a96  102f 001c
        ori.b   #0x87,(0x1c,%sp)                | e81a9a  002f 0087 001c
        movem.l %d0-%d2/%a0-%a3,(0x3d8,%a2)     | e81aa0  48ea 0f07 03d8
        st      (STOP_$WATCH_TRACE_FLAG).l      | e81aa6  50f9 00e2 1596
        movem.l (%sp)+,%d0-%d2/%a0-%a3          | e81aac  4cdf 0f07
        rte                                     | e81ab0  4e73
STOP_$WATCH_TRACE:
        movem.l %d0-%d2/%a0-%a3,-(%sp)          | e81ab2  48e7 e0f0
        movem.l (.Lsaved_regs:w,%pc),%d0-%d2/%a0-%a3| e81ab6  4cfa 0f07 0132
        sf      (STOP_$WATCH_TRACE_FLAG).l      | e81abc  51f9 00e2 1596
        move.b  %d0,(0x1c,%sp)                  | e81ac2  1f40 001c
        btst    #8,%d1                          | e81ac6  0801 0008
        bne.w   stop_$watch_trace_exit          | e81aca  6600 00a6
        move.w  %d1,(%a0)                       | e81ace  3081
        move.w  (PROC1_$CURRENT).l,%d1          | e81ad0  3239 00e2 0608
        move.l  (0x8,%a1),%d0                   | e81ad6  2029 0008
        beq.s   .Le81aec                        | e81ada  6710
        movea.l %d0,%a0                         | e81adc  2040
        btst    #5,(0x10,%a0)                   | e81ade  0828 0005 0010
        beq.s   .Le81b44                        | e81ae4  675e
        cmp.w   (0x12,%a0),%d1                  | e81ae6  b268 0012
        bne.s   .Le81b44                        | e81aea  6658
.Le81aec:
        bset    #5,(0x10,%a1)                   | e81aec  08e9 0005 0010
        beq.s   .Le81afa                        | e81af2  6706
        addq.l  #1,(0x18,%a1)                   | e81af4  52a9 0018
        bra.s   .Le81b44                        | e81af8  604a
.Le81afa:
        move.w  %d1,(0x12,%a1)                  | e81afa  3341 0012
        bsr.s   STOP_$READ_CPUT                 | e81afe  6154
        move.l  %d1,(0x2c,%a1)                  | e81b00  2341 002c
        move.w  (0x12,%a1),%d0                  | e81b04  3029 0012
        lsl.w   #2,%d0                          | e81b08  e548
        lea     (.Ltrap_counts:w,%pc),%a0       | e81b0a  41fa 0104
        move.l  (0x0,%a0,%d0.w),(0x34,%a1)      | e81b0e  2370 0000 0034
        addq.l  #1,(0x0,%a0,%d0.w)              | e81b14  52b0 0000
        bsr.s   STOP_$READ_CLOCK                | e81b18  6142
        move.l  %d1,(0x30,%a1)                  | e81b1a  2341 0030
        move.l  (.Ltrap_counts:w,%pc),(0x38,%a1)| e81b1e  237a 00f0 0038
        btst    #6,(0x10,%a1)                   | e81b24  0829 0006 0010
        bne.s   .Le81b44                        | e81b2a  6618
        move.l  %a3,(0x4,%a1)                   | e81b2c  234b 0004
        move.w  (%a3),(0xe,%a1)                 | e81b30  3353 000e
        suba.l  #.Lslots,%a1                    | e81b34  93fc 00e8 1d28
        move.l  %a1,%d0                         | e81b3a  2009
        lsr.w   #6,%d0                          | e81b3c  ec48
        .short  0xd07c; .short 0xa100           | e81b3e  d07c a100  add.w   #0xA100,%d0, the <ea>=#imm form
        move.w  %d0,(%a3)                       | e81b42  3680
.Le81b44:
        addq.l  #1,(0x3fc,%a2)                  | e81b44  52aa 03fc
        jsr     CACHE_$CLEAR                    | e81b48  4eb9 00e2 42d4
        movem.l (%sp)+,%d0-%d2/%a0-%a3          | e81b4e  4cdf 0f07
        rte                                     | e81b52  4e73
STOP_$READ_CPUT:
        lea     (PROC1_$GET_CPUT).l,%a0         | e81b54  41f9 00e2 0894
        bra.s   .Le81b62                        | e81b5a  6006
STOP_$READ_CLOCK:
        lea     (TIME_$CLOCK).l,%a0             | e81b5c  41f9 00e2 afd6
.Le81b62:
        move.l  %a1,-(%sp)                      | e81b62  2f09
        subq.w  #6,%sp                          | e81b64  5d4f
        pea     (%sp)                           | e81b66  4857
        jsr     (%a0)                           | e81b68  4e90
        addq.w  #6,%sp                          | e81b6a  5c4f
        move.l  (%sp)+,%d1                      | e81b6c  221f
        movea.l (%sp)+,%a1                      | e81b6e  225f
        rts                                     | e81b70  4e75
stop_$watch_trace_exit:
        btst    #6,(0x10,%a1)                   | e81b72  0829 0006 0010
        beq.s   .Le81b7e                        | e81b78  6704
        move.w  %d1,(%a0)                       | e81b7a  3081
        bra.s   .Le81b82                        | e81b7c  6004
.Le81b7e:
        clr.l   (0x4,%a1)                       | e81b7e  42a9 0004
.Le81b82:
        bclr    #5,(0x10,%a1)                   | e81b82  08a9 0005 0010
        beq.s   .Le81b44                        | e81b88  67ba
        move.w  (0x12,%a1),%d2                  | e81b8a  3429 0012
        cmp.w   (PROC1_$CURRENT).l,%d2          | e81b8e  b479 00e2 0608
        bne.s   .Le81b44                        | e81b94  66ae
        bsr.s   STOP_$READ_CPUT                 | e81b96  61bc
        sub.l   (0x2c,%a1),%d1                  | e81b98  92a9 002c
        sub.l   (.Lsw_overhead:w,%pc),%d1       | e81b9c  92ba 006a
        bge.s   .Le81ba4                        | e81ba0  6c02
        clr.l   %d1                             | e81ba2  4281
.Le81ba4:
        add.l   %d1,(0x1c,%a1)                  | e81ba4  d3a9 001c
        lsl.w   #2,%d2                          | e81ba8  e54a
        lea     (.Ltrap_counts:w,%pc),%a0       | e81baa  41fa 0064
        move.l  (0x0,%a0,%d2.w),%d1             | e81bae  2230 2000
        addq.l  #1,%d1                          | e81bb2  5281
        move.l  %d1,(0x0,%a0,%d2.w)             | e81bb4  2181 2000
        subq.l  #2,%d1                          | e81bb8  5581
        sub.l   (0x34,%a1),%d1                  | e81bba  92a9 0034
        add.l   %d1,(0x24,%a1)                  | e81bbe  d3a9 0024
        bsr.s   STOP_$READ_CLOCK                | e81bc2  6198
        sub.l   (0x30,%a1),%d1                  | e81bc4  92a9 0030
        sub.l   (.Lsw_overhead:w,%pc),%d1       | e81bc8  92ba 003e
        bge.s   .Le81bd0                        | e81bcc  6c02
        clr.l   %d1                             | e81bce  4281
.Le81bd0:
        add.l   %d1,(0x20,%a1)                  | e81bd0  d3a9 0020
        move.l  (.Ltrap_counts:w,%pc),%d1       | e81bd4  223a 003a
        subq.l  #1,%d1                          | e81bd8  5381
        sub.l   (0x38,%a1),%d1                  | e81bda  92a9 0038
        add.l   %d1,(0x28,%a1)                  | e81bde  d3a9 0028
        addq.l  #1,(0x14,%a1)                   | e81be2  52a9 0014
        bra.w   .Le81b44                        | e81be6  6000 ff5c
        rts                                     | e81bea  4e75

| The module's data, 0xE81BEC..0xE82128 (A5+0x3D8 .. A5+0x914).
.Lsaved_regs:                           | 0xE81BEC  A5+0x3D8
        .space  7 * 4
.Lsw_overhead:                          | 0xE81C08  A5+0x3F4
        .long   0
.Lcalibration:                          | 0xE81C0C  A5+0x3F8
        .long   0
.Ltrap_counts:                          | 0xE81C10  A5+0x3FC, per pid 0..64
        .space  65 * 4
.Lcalib_patch:                          | 0xE81D14  A5+0x500
        .long   STOP_$NULL_PROC         | entry
        .long   0                       | exit
.Lwire_start:                           | 0xE81D1C  A5+0x508
        .long   STOP_$WATCH
.Lwire_end:                             | 0xE81D20  A5+0x50C
        .long   OS_DATA_SHUTWIRED
.Lwired:                                | 0xE81D24  A5+0x510
        .word   0
.Lwire_count:                           | 0xE81D26  A5+0x512
        .word   4
.Lslots:                                | 0xE81D28  A5+0x514, 16 slots
        .space  16 * 0x40
