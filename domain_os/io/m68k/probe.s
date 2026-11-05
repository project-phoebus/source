/*
 * io_$probe - Hardware probe with bus error recovery (m68k/SAU2, SAU5,
 * SAU9)
 *
 * The SAU2, SAU3 and SAU5 images have the same code here except the bus-error
 * recovery stub, where the SAU5 (base/config.ins.pas's part `vme_bus')
 * also calls VME_$SAVE_VME and writes 0x60 to VME_CTL + 0x41 before it
 * returns false: TESTPAGE is 0x74 bytes there (`D E2A260 TESTPAGE size
 * = 74'), the SAU2's 0x60.  The address and byte columns below are the
 * SAU2 image's, except on the lines of the `.if vme_bus' arm, which carry
 * the SAU5 image's.  On the SAU9 (`parity_err_regs': its MMU's error
 * registers) the probe clears the current process's fault status word
 * (PROC1_$CURRENT_PCB + 0x5C) and pulses MMU_CCR bit 4 where the SAU2
 * clears the MMU status byte (TESTPAGE 0x74 bytes, `D 3C42C830 TESTPAGE
 * size = 74'); those lines carry the SAU9 image's addresses.
 * The SAU8 (`cpu_status_register') clears the process's fault status
 * word and the CPU status register (MMU) before the access, and the
 * register again after it (`D 3C2B0D8 TESTPAGE size = 70'); those lines
 * carry the SAU8 image's addresses.
 * The SAU4 clears its MMU status word (MMU + 2, `mmu_status_word') where
 * the SAU2 clears the status byte, and after a completed access reads the
 * word at 0x400 while the recovery is still armed (`probe_settle_read';
 * `D F82B7E8 TESTPAGE size = 64'); those lines carry the SAU4 image's
 * addresses.
 * The SAU6 clears bit 6 of the MMU status byte (MMU + 3) alone
 * (`mmu_status_bit_6'; `D 7802C680 TESTPAGE size = 68'), waits after a
 * completed access with two calls of its own return
 * (`probe_settle_calls'), and does not save the VME state after a bus
 * error, which its FIM_$BUS_ERR has done (`fim_vme_ack'); those lines
 * carry the SAU6 image's addresses.
 *
 * Byte gate (tools/asm_compare.py, `make check'): encodings identical
 * to the image (modulo the documented widenings); address operands
 * resolve to our objects.
 *
 * Touches a device register with interrupts off and a temporary bus-error
 * handler installed, and reports whether the access completed.  Used by
 * flp/, prom/, peb/, win/ and smd/ to decide whether a controller is
 * present.
 *
 * Original address: 0x00E29138
 * Extent: 0x00E29138 .. 0x00E29197 (the 54-byte entry Ghidra knows about
 * plus the jump table, the four probe bodies, the common exit and the
 * bus-error recovery stub that follow it).
 *
 * Image bytes (`gsk read 0xe29138 0x60`):
 *   00e29138  48 e7 10 28 20 6f 00 10  30 10 e3 48 22 6f 00 14
 *   00e29148  22 51 24 6f 00 18 40 c3  00 7c 07 00 41 fa 00 3c
 *   00e29158  23 c8 00 e2 18 cc 22 0f  42 39 00 ff b4 03 41 fa
 *   00e29168  00 06 4e f0 00 00 60 0c  60 0e 60 04 32 92 60 0a
 *   00e29178  12 92 60 06 14 91 60 02  34 91 50 c0 42 b9 00 e2
 *   00e29188  18 cc 46 c3 4c df 14 08  4e 75 2e 41 51 c0 60 ec
 *
 * Register usage:
 *   A1 = the hardware address (two levels of indirection from param_2)
 *   A2 = the caller's data buffer
 *   D0 = jump table byte offset (*param_1 * 2), then the result byte
 *   D1 = SP saved for the bus-error stub to restore
 *   D3 = saved SR
 *
 * Parameters (stack, all by reference):
 *   param_1 = pointer to the probe-type word (0..3)
 *   param_2 = pointer to a pointer to the hardware location
 *   param_3 = pointer to the data buffer read into or written from
 *
 * Probe types (the four jump-table cases):
 *   0 = read  byte:  move.b (A1),(A2)
 *   1 = read  word:  move.w (A1),(A2)
 *   2 = write byte:  move.b (A2),(A1)
 *   3 = write word:  move.w (A2),(A1)
 * The type word is not range checked; a value outside 0..3 jumps into the
 * middle of the code that follows the table.
 *
 * Returns:
 *   D0.b = 0xFF (st) if the access completed, 0 (sf) if it bus-errored.
 *   Domain booleans are 0xFF/0x00 and are tested with tst.b / bmi, so
 *   "found" is the negative value.
 *
 * This is hand-written assembly -- it takes a SR snapshot, patches the
 * global bus-error vector cell, longjmps back through a saved SP, and
 * dispatches through a table of 2-byte branches -- so it is transcribed
 * rather than translated: nothing compiled behaves this way.
 */

        .include "base/config.inc"

        .section ".text.io_$probe","ax",@progbits
        .even

        /* Patch cell read by FIM_$BUS_ERR: when non-zero the bus-error
         * handler jumps here instead of crashing.  BUS_ERROR_SWITCH (map
         * 0x00E218CC) is the operand of JMP_TO_BUS_ERR in
         * fim/m68k/bus_err.s, used by name. */
        .extern BUS_ERROR_SWITCH
        /* SAU2 MMU status register (hardware, legitimately absolute). */
        .equ    MMU_STATUS_REG,     0x00FFB403

        /* TESTPAGE is the map's name for this routine (`D E29138 TESTPAGE
         * size = 60', its one symbol; module-local, no `$'); io_$probe names the
         * section, which tools/gen_layout_ld.py ANCHORS keys. */
        .globl  TESTPAGE
        .globl  io_$probe
        .globl  _io_$probe
TESTPAGE:
io_$probe:
_io_$probe:
        movem.l %d3/%a2/%a4, -(%sp)     /* 0x00E29138 12 bytes saved       */

        /* Arguments are at SP0+4/+8/+0xC; SP is now 12 lower. */
        movea.l (0x10,%sp), %a0         /* 0x00E2913C A0 = &type           */
        move.w  (%a0), %d0              /* 0x00E29140 D0.w = type          */
        lsl.w   #1, %d0                 /* 0x00E29142 * 2 = table offset   */

        movea.l (0x14,%sp), %a1         /* 0x00E29144 A1 = &hw_addr        */
        movea.l (%a1), %a1              /* 0x00E29148 A1 = hw_addr         */

        movea.l (0x18,%sp), %a2         /* 0x00E2914A A2 = data buffer     */

        move    %sr, %d3                /* 0x00E2914E save SR              */
        ori     #0x0700, %sr            /* 0x00E29150 IPL 7                */

        lea     .Lbus_error(%pc), %a0   /* 0x00E29154 -> 0x00E29192        */
        move.l  %a0, (BUS_ERROR_SWITCH).l /* 0x00E29158 arm the recovery   */

        move.l  %sp, %d1                /* 0x00E2915E SP for the stub      */

        .if parity_err_regs
        /* sau9: the current process's fault status word cleared, and a
           pending memory error cleared with a pulse of MMU_CCR bit 4 */
        movea.l (PROC1_$CURRENT_PCB).l, %a0 /* sau9 0x3C42C858             */
        clr.w   (0x5c,%a0)              /* sau9 0x3C42C85E                 */
        bset    #4, (MMU_CCR).l         /* sau9 0x3C42C862                 */
        bclr    #4, (MMU_CCR).l         /* sau9 0x3C42C86A                 */
        .elseif cpu_status_register
        /* sau8: the current process's fault status word and the CPU
           status register cleared */
        movea.l (PROC1_$CURRENT_PCB).l, %a0 /* sau8 0x3C2B100              */
        clr.w   (0x5c,%a0)              /* sau8 0x3C2B106                  */
        clr.w   (MMU).l                 /* sau8 0x3C2B10A  4279 03ff b400  */
        .elseif mmu_status_word
        clr.w   (MMU+2).l               /* sau4 0xF82B810  4279 0fff b402  */
        .elseif mmu_status_bit_6
        bclr    #6, (MMU+3).l           /* sau6 0x7802C6A8 08b9 0006 7fff b403 */
        .else
        clr.b   MMU_STATUS_REG          /* 0x00E29160 fresh fault status   */
        .endif

        lea     .Ljump_table(%pc), %a0  /* 0x00E29166 -> 0x00E2916E        */
        jmp     (0,%a0,%d0.w)           /* 0x00E2916A                      */

.Ljump_table:                           /* 0x00E2916E                      */
        bra.b   .Lread_byte             /* 0x00E2916E type 0 -> 0x00E2917C */
        bra.b   .Lread_word             /* 0x00E29170 type 1 -> 0x00E29180 */
        bra.b   .Lwrite_byte            /* 0x00E29172 type 2 -> 0x00E29178 */
                                        /* type 3 falls into the body at   */
                                        /* 0x00E29174, which is the table  */
                                        /* entry itself                    */
.Lwrite_word:
        move.w  (%a2), (%a1)            /* 0x00E29174                      */
        bra.b   .Lprobe_ok              /* 0x00E29176 -> 0x00E29182        */

.Lwrite_byte:
        move.b  (%a2), (%a1)            /* 0x00E29178                      */
        bra.b   .Lprobe_ok              /* 0x00E2917A                      */

.Lread_byte:
        move.b  (%a1), (%a2)            /* 0x00E2917C                      */
        bra.b   .Lprobe_ok              /* 0x00E2917E                      */

.Lread_word:
        move.w  (%a1), (%a2)            /* 0x00E29180                      */
                                        /* falls through                   */
.Lprobe_ok:
        st      %d0                     /* 0x00E29182 D0.b = 0xFF          */
        .if probe_settle_read
        tst.w   (0x400).w               /* sau4 0xF82B834  4a78 0400       */
        .elseif probe_settle_calls
        bsr.s   .Lprobe_rts             /* sau6 0x7802C6CE 610e: a wait    */
        bsr.s   .Lprobe_rts             /* sau6 0x7802C6D0 610c            */
        .endif

.Lexit:
        clr.l   (BUS_ERROR_SWITCH).l    /* 0x00E29184 disarm the recovery  */
        .if cpu_status_register
        clr.w   (MMU).l                 /* sau8 0x3C2B134: the CPU status  */
        .endif
        move    %d3, %sr                /* 0x00E2918A restore SR/IPL       */
        movem.l (%sp)+, %d3/%a2/%a4     /* 0x00E2918C                      */
.Lprobe_rts:
        rts                             /* 0x00E29190                      */

.Lbus_error:                            /* 0x00E29192, entered from        */
                                        /* FIM_$BUS_ERR, not by a branch   */
        movea.l %d1, %sp                /* 0x00E29192 unwind to the probe  */
        .if vme_bus && !fim_vme_ack     /* the SAU6's bus error handler saves the VME state */
        lea     (VME_$SAVE_VME).l, %a0  /* sau5 0x00E2A2BC the VME state   */
        jsr     (%a0)                   /* sau5 0x00E2A2C2                 */
        lea     (VME_CTL).l, %a0        /* sau5 0x00E2A2C4 0xFF9400 (SAU5  */
                                        /* map), an absolute symbol        */
        move.b  #0x60, (0x41,%a0)       /* sau5 0x00E2A2CA                 */
        .endif
        sf      %d0                     /* 0x00E29194 D0.b = 0x00          */
        bra.b   .Lexit                  /* 0x00E29196 -> 0x00E29184        */
        .if probe_settle_calls
        .short  0                       /* sau6 0x7802C6E6: the segment rounded to a longword */
        .endif
