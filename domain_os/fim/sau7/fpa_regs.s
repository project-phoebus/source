/*
 * fim/sau7/fpa_regs.s - the floating-point accelerator's register and
 * wrap routines, FIM_$FP_GET_FPREGS .. FIM_$FP_REX_DP_CVT (SAU7)
 *
 * SAU7 map, in "D 3C425840 FIM_UNWIRED size = AF4": the 20 routines from
 * FIM_$FP_GET_FPREGS (0x3C425D2E) after FIM_$SETUP_RETURN (fim/m68k/
 * fault_return.s) to the segment's end (0x3C426333, its last word the
 * pad), each in its own section keyed by its map symbol.  FIM_FP's
 * compiled routines, FIM_$FP_INTERLUDE_HANDLER's, call them for the
 * accelerator's exception (fim/sau7/fpa.s's bus error entry).
 *
 * The accelerator's registers (fim/sau7/fpa.s has the whole window):
 * register n (0 .. 15) at 16#FFFF8000 + n * 16#400, read at + 16#14 and
 * + 16#18, written at + 16#0C and + 16#14; the twelve WTK status bytes
 * read at 16#FFFF8083 .. 16#FFFF80BB and written at 16#FFFF80C3 ..
 * 16#FFFF80FB (+ 16#40), the status of an operation in the byte read at
 * 16#FFFF809B; an operation on register 0 (and 1) started by a byte or
 * word access at its address in 16#FFFF8000 .. 16#FFFF806B; the control
 * and status register (FPCSR) and the exception register (EIR) absolute
 * long.  All take their arguments on the stack, by reference, and
 * return with `rts' (FIM_$FP_GET_FPCSR and FIM_$FP_GET_EIR their value
 * in D0); none saves a register.
 *
 * The re-execute routines (FIM_$FP_REX_*) load the operands into
 * registers 0 and 1, start the operation their op code selects (other
 * codes give the status 16#FF), and store the result and the status
 * word; the monadic ones do op 1 (copy) and op 2 (clear the sign) in
 * the CPU, status 0.  The Apollo assembler's <ea>=#imm forms (cmp.w,
 * and.l #imm,D0), which gas spells cmpi/andi, are written as `.short'.
 *
 * Byte gate (the SAU7 has no asm_compare tables yet): assembled with
 * `m68k-elf-as -m68030 -m68881' and compared with the image at the
 * map's addresses by tools/asm_compare.py's rules.  The address and
 * byte columns are the SAU7 image's.
 */

        .include "base/config.inc"
        .if fpa_board

        .globl  FIM_$FP_GET_FPREGS
        .globl  FIM_$FP_PUT_FPREGS
        .globl  FIM_$FP_GET_WTK_STATUS
        .globl  FIM_$FP_PUT_WTK_STATUS
        .globl  FIM_$FP_GET_FPCSR
        .globl  FIM_$FP_PUT_FPCSR
        .globl  FIM_$FP_GET_EIR
        .globl  FIM_$FP_PUT_EIR
        .globl  FIM_$FP_SUNWRAP
        .globl  FIM_$FP_DUNWRAP
        .globl  FIM_$FP_SUNWRAPI
        .globl  FIM_$FP_DUNWRAPI
        .globl  FIM_$FP_SPWRAP
        .globl  FIM_$FP_DPWRAP
        .globl  FIM_$FP_REX_SP_DIADIC
        .globl  FIM_$FP_REX_DP_DIADIC
        .globl  FIM_$FP_REX_SP_MONADIC
        .globl  FIM_$FP_REX_DP_MONADIC
        .globl  FIM_$FP_REX_SP_CVT
        .globl  FIM_$FP_REX_DP_CVT

/* FIM_$FP_GET_FPREGS(regs) - 0x3C425D2E: the 16 registers' 32 longwords
   into regs, register 0 first. */
        .section ".text.FIM_$FP_GET_FPREGS","ax",@progbits
        .even
FIM_$FP_GET_FPREGS:
        movea.l (0x4,%sp),%a0                   | 3c425d2e  206f 0004
        move.l  (0xffff8014).w,(%a0)+           | 3c425d32  20f8 8014
        move.l  (0xffff8018).w,(%a0)+           | 3c425d36  20f8 8018
        move.l  (0xffff8414).w,(%a0)+           | 3c425d3a  20f8 8414
        move.l  (0xffff8418).w,(%a0)+           | 3c425d3e  20f8 8418
        move.l  (0xffff8814).w,(%a0)+           | 3c425d42  20f8 8814
        move.l  (0xffff8818).w,(%a0)+           | 3c425d46  20f8 8818
        move.l  (0xffff8c14).w,(%a0)+           | 3c425d4a  20f8 8c14
        move.l  (0xffff8c18).w,(%a0)+           | 3c425d4e  20f8 8c18
        move.l  (0xffff9014).w,(%a0)+           | 3c425d52  20f8 9014
        move.l  (0xffff9018).w,(%a0)+           | 3c425d56  20f8 9018
        move.l  (0xffff9414).w,(%a0)+           | 3c425d5a  20f8 9414
        move.l  (0xffff9418).w,(%a0)+           | 3c425d5e  20f8 9418
        move.l  (0xffff9814).w,(%a0)+           | 3c425d62  20f8 9814
        move.l  (0xffff9818).w,(%a0)+           | 3c425d66  20f8 9818
        move.l  (0xffff9c14).w,(%a0)+           | 3c425d6a  20f8 9c14
        move.l  (0xffff9c18).w,(%a0)+           | 3c425d6e  20f8 9c18
        move.l  (0xffffa014).w,(%a0)+           | 3c425d72  20f8 a014
        move.l  (0xffffa018).w,(%a0)+           | 3c425d76  20f8 a018
        move.l  (0xffffa414).w,(%a0)+           | 3c425d7a  20f8 a414
        move.l  (0xffffa418).w,(%a0)+           | 3c425d7e  20f8 a418
        move.l  (0xffffa814).w,(%a0)+           | 3c425d82  20f8 a814
        move.l  (0xffffa818).w,(%a0)+           | 3c425d86  20f8 a818
        move.l  (0xffffac14).w,(%a0)+           | 3c425d8a  20f8 ac14
        move.l  (0xffffac18).w,(%a0)+           | 3c425d8e  20f8 ac18
        move.l  (0xffffb014).w,(%a0)+           | 3c425d92  20f8 b014
        move.l  (0xffffb018).w,(%a0)+           | 3c425d96  20f8 b018
        move.l  (0xffffb414).w,(%a0)+           | 3c425d9a  20f8 b414
        move.l  (0xffffb418).w,(%a0)+           | 3c425d9e  20f8 b418
        move.l  (0xffffb814).w,(%a0)+           | 3c425da2  20f8 b814
        move.l  (0xffffb818).w,(%a0)+           | 3c425da6  20f8 b818
        move.l  (0xffffbc14).w,(%a0)+           | 3c425daa  20f8 bc14
        move.l  (0xffffbc18).w,(%a0)+           | 3c425dae  20f8 bc18
        rts                                     | 3c425db2  4e75

/* FIM_$FP_PUT_FPREGS(regs) - 0x3C425DB4: the 32 longwords from regs back
   into the 16 registers. */
        .section ".text.FIM_$FP_PUT_FPREGS","ax",@progbits
        .even
FIM_$FP_PUT_FPREGS:
        movea.l (0x4,%sp),%a0                   | 3c425db4  206f 0004
        move.l  (%a0)+,(0xffff800c).w           | 3c425db8  21d8 800c
        move.l  (%a0)+,(0xffff8014).w           | 3c425dbc  21d8 8014
        move.l  (%a0)+,(0xffff840c).w           | 3c425dc0  21d8 840c
        move.l  (%a0)+,(0xffff8414).w           | 3c425dc4  21d8 8414
        move.l  (%a0)+,(0xffff880c).w           | 3c425dc8  21d8 880c
        move.l  (%a0)+,(0xffff8814).w           | 3c425dcc  21d8 8814
        move.l  (%a0)+,(0xffff8c0c).w           | 3c425dd0  21d8 8c0c
        move.l  (%a0)+,(0xffff8c14).w           | 3c425dd4  21d8 8c14
        move.l  (%a0)+,(0xffff900c).w           | 3c425dd8  21d8 900c
        move.l  (%a0)+,(0xffff9014).w           | 3c425ddc  21d8 9014
        move.l  (%a0)+,(0xffff940c).w           | 3c425de0  21d8 940c
        move.l  (%a0)+,(0xffff9414).w           | 3c425de4  21d8 9414
        move.l  (%a0)+,(0xffff980c).w           | 3c425de8  21d8 980c
        move.l  (%a0)+,(0xffff9814).w           | 3c425dec  21d8 9814
        move.l  (%a0)+,(0xffff9c0c).w           | 3c425df0  21d8 9c0c
        move.l  (%a0)+,(0xffff9c14).w           | 3c425df4  21d8 9c14
        move.l  (%a0)+,(0xffffa00c).w           | 3c425df8  21d8 a00c
        move.l  (%a0)+,(0xffffa014).w           | 3c425dfc  21d8 a014
        move.l  (%a0)+,(0xffffa40c).w           | 3c425e00  21d8 a40c
        move.l  (%a0)+,(0xffffa414).w           | 3c425e04  21d8 a414
        move.l  (%a0)+,(0xffffa80c).w           | 3c425e08  21d8 a80c
        move.l  (%a0)+,(0xffffa814).w           | 3c425e0c  21d8 a814
        move.l  (%a0)+,(0xffffac0c).w           | 3c425e10  21d8 ac0c
        move.l  (%a0)+,(0xffffac14).w           | 3c425e14  21d8 ac14
        move.l  (%a0)+,(0xffffb00c).w           | 3c425e18  21d8 b00c
        move.l  (%a0)+,(0xffffb014).w           | 3c425e1c  21d8 b014
        move.l  (%a0)+,(0xffffb40c).w           | 3c425e20  21d8 b40c
        move.l  (%a0)+,(0xffffb414).w           | 3c425e24  21d8 b414
        move.l  (%a0)+,(0xffffb80c).w           | 3c425e28  21d8 b80c
        move.l  (%a0)+,(0xffffb814).w           | 3c425e2c  21d8 b814
        move.l  (%a0)+,(0xffffbc0c).w           | 3c425e30  21d8 bc0c
        move.l  (%a0)+,(0xffffbc14).w           | 3c425e34  21d8 bc14
        rts                                     | 3c425e38  4e75

/* FIM_$FP_GET_WTK_STATUS(status) - 0x3C425E3A: the twelve WTK status
   bytes into status, a word each (high byte zero); the bytes written at
   16#FFFF80DB and 16#FFFF80FB are cleared after the fourth and the
   twelfth. */
        .section ".text.FIM_$FP_GET_WTK_STATUS","ax",@progbits
        .even
FIM_$FP_GET_WTK_STATUS:
        movea.l (0x4,%sp),%a0                   | 3c425e3a  206f 0004
        move.w  #0,%d0                          | 3c425e3e  303c 0000
        move.b  (0xffff8083).w,%d0              | 3c425e42  1038 8083
        move.w  %d0,(%a0)+                      | 3c425e46  30c0
        move.b  (0xffff808b).w,%d0              | 3c425e48  1038 808b
        move.w  %d0,(%a0)+                      | 3c425e4c  30c0
        move.b  (0xffff8093).w,%d0              | 3c425e4e  1038 8093
        move.w  %d0,(%a0)+                      | 3c425e52  30c0
        move.b  (0xffff809b).w,%d0              | 3c425e54  1038 809b
        move.w  %d0,(%a0)+                      | 3c425e58  30c0
        clr.b   (0xffff80db).w                  | 3c425e5a  4238 80db
        move.b  (0xffff8087).w,%d0              | 3c425e5e  1038 8087
        move.w  %d0,(%a0)+                      | 3c425e62  30c0
        move.b  (0xffff808f).w,%d0              | 3c425e64  1038 808f
        move.w  %d0,(%a0)+                      | 3c425e68  30c0
        move.b  (0xffff8097).w,%d0              | 3c425e6a  1038 8097
        move.w  %d0,(%a0)+                      | 3c425e6e  30c0
        move.b  (0xffff809f).w,%d0              | 3c425e70  1038 809f
        move.w  %d0,(%a0)+                      | 3c425e74  30c0
        move.b  (0xffff80a3).w,%d0              | 3c425e76  1038 80a3
        move.w  %d0,(%a0)+                      | 3c425e7a  30c0
        move.b  (0xffff80ab).w,%d0              | 3c425e7c  1038 80ab
        move.w  %d0,(%a0)+                      | 3c425e80  30c0
        move.b  (0xffff80b3).w,%d0              | 3c425e82  1038 80b3
        move.w  %d0,(%a0)+                      | 3c425e86  30c0
        move.b  (0xffff80bb).w,%d0              | 3c425e88  1038 80bb
        move.w  %d0,(%a0)+                      | 3c425e8c  30c0
        clr.b   (0xffff80fb).w                  | 3c425e8e  4238 80fb
        rts                                     | 3c425e92  4e75

/* FIM_$FP_PUT_WTK_STATUS(status) - 0x3C425E94: the twelve words' low
   bytes back into the WTK status bytes. */
        .section ".text.FIM_$FP_PUT_WTK_STATUS","ax",@progbits
        .even
FIM_$FP_PUT_WTK_STATUS:
        movea.l (0x4,%sp),%a0                   | 3c425e94  206f 0004
        move.w  (%a0)+,%d0                      | 3c425e98  3018
        move.b  %d0,(0xffff80c3).w              | 3c425e9a  11c0 80c3
        move.w  (%a0)+,%d0                      | 3c425e9e  3018
        move.b  %d0,(0xffff80cb).w              | 3c425ea0  11c0 80cb
        move.w  (%a0)+,%d0                      | 3c425ea4  3018
        move.b  %d0,(0xffff80d3).w              | 3c425ea6  11c0 80d3
        move.w  (%a0)+,%d0                      | 3c425eaa  3018
        move.b  %d0,(0xffff80db).w              | 3c425eac  11c0 80db
        move.w  (%a0)+,%d0                      | 3c425eb0  3018
        move.b  %d0,(0xffff80c7).w              | 3c425eb2  11c0 80c7
        move.w  (%a0)+,%d0                      | 3c425eb6  3018
        move.b  %d0,(0xffff80cf).w              | 3c425eb8  11c0 80cf
        move.w  (%a0)+,%d0                      | 3c425ebc  3018
        move.b  %d0,(0xffff80d7).w              | 3c425ebe  11c0 80d7
        move.w  (%a0)+,%d0                      | 3c425ec2  3018
        move.b  %d0,(0xffff80df).w              | 3c425ec4  11c0 80df
        move.w  (%a0)+,%d0                      | 3c425ec8  3018
        move.b  %d0,(0xffff80e3).w              | 3c425eca  11c0 80e3
        move.w  (%a0)+,%d0                      | 3c425ece  3018
        move.b  %d0,(0xffff80eb).w              | 3c425ed0  11c0 80eb
        move.w  (%a0)+,%d0                      | 3c425ed4  3018
        move.b  %d0,(0xffff80f3).w              | 3c425ed6  11c0 80f3
        move.w  (%a0)+,%d0                      | 3c425eda  3018
        move.b  %d0,(0xffff80fb).w              | 3c425edc  11c0 80fb
        rts                                     | 3c425ee0  4e75

/* FIM_$FP_GET_FPCSR - 0x3C425EE2: the control and status register, in
   D0. */
        .section ".text.FIM_$FP_GET_FPCSR","ax",@progbits
        .even
FIM_$FP_GET_FPCSR:
        move.l  (0xfff90000).l,%d0              | 3c425ee2  2039 fff9 0000
        rts                                     | 3c425ee8  4e75

/* FIM_$FP_PUT_FPCSR(value) - 0x3C425EEA */
        .section ".text.FIM_$FP_PUT_FPCSR","ax",@progbits
        .even
FIM_$FP_PUT_FPCSR:
        movea.l (0x4,%sp),%a0                   | 3c425eea  206f 0004
        move.l  (%a0),(0xfff90000).l            | 3c425eee  23d0 fff9 0000
        rts                                     | 3c425ef4  4e75

/* FIM_$FP_GET_EIR - 0x3C425EF6: the exception register, in D0. */
        .section ".text.FIM_$FP_GET_EIR","ax",@progbits
        .even
FIM_$FP_GET_EIR:
        move.l  (0xfff80000).l,%d0              | 3c425ef6  2039 fff8 0000
        rts                                     | 3c425efc  4e75

/* FIM_$FP_PUT_EIR(value) - 0x3C425EFE */
        .section ".text.FIM_$FP_PUT_EIR","ax",@progbits
        .even
FIM_$FP_PUT_EIR:
        movea.l (0x4,%sp),%a0                   | 3c425efe  206f 0004
        move.l  (%a0),(0xfff80000).l            | 3c425f02  23d0 fff8 0000
        rts                                     | 3c425f08  4e75

/* FIM_$FP_SUNWRAP(x, status) - 0x3C425F0A: the single-precision x
   through the operation at 16#FFFF8014, in place, with the WTK status
   byte 16#FFFF80D3 set to 2 around it; status = the operation's. */
        .section ".text.FIM_$FP_SUNWRAP","ax",@progbits
        .even
FIM_$FP_SUNWRAP:
        movea.l (0x4,%sp),%a0                   | 3c425f0a  206f 0004
        move.l  (%a0),(0xffff800c).w            | 3c425f0e  21d0 800c
        clr.b   (0xffff80db).w                  | 3c425f12  4238 80db
        move.b  #2,%d0                          | 3c425f16  103c 0002
        move.b  %d0,(0xffff80d3).w              | 3c425f1a  11c0 80d3
        clr.b   (0xffff8014).w                  | 3c425f1e  4238 8014
        move.l  (0xffff8014).w,(%a0)            | 3c425f22  20b8 8014
        movea.l (0x8,%sp),%a0                   | 3c425f26  206f 0008
        move.b  (0xffff809b).w,%d0              | 3c425f2a  1038 809b
        move.w  %d0,(%a0)                       | 3c425f2e  3080
        clr.b   (0xffff80d3).w                  | 3c425f30  4238 80d3
        clr.b   (0xffff80db).w                  | 3c425f34  4238 80db
        clr.b   (0xffff80fb).w                  | 3c425f38  4238 80fb
        rts                                     | 3c425f3c  4e75

/* FIM_$FP_DUNWRAP(x, status) - 0x3C425F3E: the double-precision x
   through the operation at 16#FFFF8010, as FIM_$FP_SUNWRAP. */
        .section ".text.FIM_$FP_DUNWRAP","ax",@progbits
        .even
FIM_$FP_DUNWRAP:
        movea.l (0x4,%sp),%a0                   | 3c425f3e  206f 0004
        move.l  (%a0),(0xffff800c).w            | 3c425f42  21d0 800c
        move.l  (0x4,%a0),(0xffff8014).w        | 3c425f46  21e8 0004 8014
        clr.b   (0xffff80db).w                  | 3c425f4c  4238 80db
        move.b  #2,%d0                          | 3c425f50  103c 0002
        move.b  %d0,(0xffff80d3).w              | 3c425f54  11c0 80d3
        clr.b   (0xffff8010).w                  | 3c425f58  4238 8010
        move.l  (0xffff8014).w,(%a0)            | 3c425f5c  20b8 8014
        move.l  (0xffff8018).w,(0x4,%a0)        | 3c425f60  2178 8018 0004
        movea.l (0x8,%sp),%a0                   | 3c425f66  206f 0008
        move.b  (0xffff809b).w,%d0              | 3c425f6a  1038 809b
        move.w  %d0,(%a0)                       | 3c425f6e  3080
        clr.b   (0xffff80d3).w                  | 3c425f70  4238 80d3
        clr.b   (0xffff80db).w                  | 3c425f74  4238 80db
        clr.b   (0xffff80fb).w                  | 3c425f78  4238 80fb
        rts                                     | 3c425f7c  4e75

/* FIM_$FP_SUNWRAPI(x, status) - 0x3C425F7E: as FIM_$FP_SUNWRAP, the
   operation at 16#FFFF801C. */
        .section ".text.FIM_$FP_SUNWRAPI","ax",@progbits
        .even
FIM_$FP_SUNWRAPI:
        movea.l (0x4,%sp),%a0                   | 3c425f7e  206f 0004
        move.l  (%a0),(0xffff800c).w            | 3c425f82  21d0 800c
        clr.b   (0xffff80db).w                  | 3c425f86  4238 80db
        move.b  #2,%d0                          | 3c425f8a  103c 0002
        move.b  %d0,(0xffff80d3).w              | 3c425f8e  11c0 80d3
        clr.b   (0xffff801c).w                  | 3c425f92  4238 801c
        move.l  (0xffff8014).w,(%a0)            | 3c425f96  20b8 8014
        movea.l (0x8,%sp),%a0                   | 3c425f9a  206f 0008
        move.b  (0xffff809b).w,%d0              | 3c425f9e  1038 809b
        move.w  %d0,(%a0)                       | 3c425fa2  3080
        clr.b   (0xffff80d3).w                  | 3c425fa4  4238 80d3
        clr.b   (0xffff80db).w                  | 3c425fa8  4238 80db
        clr.b   (0xffff80fb).w                  | 3c425fac  4238 80fb
        rts                                     | 3c425fb0  4e75

/* FIM_$FP_DUNWRAPI(x, status) - 0x3C425FB2: as FIM_$FP_DUNWRAP, the
   operation at 16#FFFF8018. */
        .section ".text.FIM_$FP_DUNWRAPI","ax",@progbits
        .even
FIM_$FP_DUNWRAPI:
        movea.l (0x4,%sp),%a0                   | 3c425fb2  206f 0004
        move.l  (%a0),(0xffff800c).w            | 3c425fb6  21d0 800c
        move.l  (0x4,%a0),(0xffff8014).w        | 3c425fba  21e8 0004 8014
        clr.b   (0xffff80db).w                  | 3c425fc0  4238 80db
        move.b  #2,%d0                          | 3c425fc4  103c 0002
        move.b  %d0,(0xffff80d3).w              | 3c425fc8  11c0 80d3
        clr.b   (0xffff8018).w                  | 3c425fcc  4238 8018
        move.l  (0xffff8014).w,(%a0)            | 3c425fd0  20b8 8014
        move.l  (0xffff8018).w,(0x4,%a0)        | 3c425fd4  2178 8018 0004
        movea.l (0x8,%sp),%a0                   | 3c425fda  206f 0008
        move.b  (0xffff809b).w,%d0              | 3c425fde  1038 809b
        move.w  %d0,(%a0)                       | 3c425fe2  3080
        clr.b   (0xffff80d3).w                  | 3c425fe4  4238 80d3
        clr.b   (0xffff80db).w                  | 3c425fe8  4238 80db
        clr.b   (0xffff80fb).w                  | 3c425fec  4238 80fb
        rts                                     | 3c425ff0  4e75

/* FIM_$FP_SPWRAP(x) - 0x3C425FF2: the single-precision x through the
   operation read at 16#FFFF8014, in place. */
        .section ".text.FIM_$FP_SPWRAP","ax",@progbits
        .even
FIM_$FP_SPWRAP:
        movea.l (0x4,%sp),%a0                   | 3c425ff2  206f 0004
        move.l  (%a0),(0xffff800c).w            | 3c425ff6  21d0 800c
        tst.b   (0xffff8014).w                  | 3c425ffa  4a38 8014
        move.l  (0xffff8014).w,(%a0)            | 3c425ffe  20b8 8014
        rts                                     | 3c426002  4e75

/* FIM_$FP_DPWRAP(x) - 0x3C426004: the double-precision x through the
   operation read at 16#FFFF8010, in place. */
        .section ".text.FIM_$FP_DPWRAP","ax",@progbits
        .even
FIM_$FP_DPWRAP:
        movea.l (0x4,%sp),%a0                   | 3c426004  206f 0004
        move.l  (%a0),(0xffff800c).w            | 3c426008  21d0 800c
        move.l  (0x4,%a0),(0xffff8014).w        | 3c42600c  21e8 0004 8014
        tst.b   (0xffff8010).w                  | 3c426012  4a38 8010
        move.l  (0xffff8014).w,(%a0)            | 3c426016  20b8 8014
        move.l  (0xffff8018).w,(0x4,%a0)        | 3c42601a  2178 8018 0004
        rts                                     | 3c426020  4e75

/* FIM_$FP_REX_SP_DIADIC(a, b, result, op, status) - 0x3C426022: the
   single-precision operation op (0 .. 3: the words at 16#FFFF8040,
   16#FFFF8044, 16#FFFF8048, 16#FFFF804C) on a and b. */
        .section ".text.FIM_$FP_REX_SP_DIADIC","ax",@progbits
        .even
FIM_$FP_REX_SP_DIADIC:
        clr.b   (0xffff80db).w                  | 3c426022  4238 80db
        clr.b   (0xffff80fb).w                  | 3c426026  4238 80fb
        movea.l (0x4,%sp),%a0                   | 3c42602a  206f 0004
        move.l  (%a0),(0xffff800c).w            | 3c42602e  21d0 800c
        movea.l (0x8,%sp),%a0                   | 3c426032  206f 0008
        move.l  (%a0),(0xffff840c).w            | 3c426036  21d0 840c
        movea.l (0x10,%sp),%a0                  | 3c42603a  206f 0010
        move.w  (%a0),%d0                       | 3c42603e  3010
        .short  0xb07c, 0x0000                  | 3c426040  b07c 0000  cmp.w #0,%d0
        beq.w   .L3c42606a                      | 3c426044  6700 0024
        .short  0xb07c, 0x0001                  | 3c426048  b07c 0001  cmp.w #1,%d0
        beq.w   .L3c42608a                      | 3c42604c  6700 003c
        .short  0xb07c, 0x0002                  | 3c426050  b07c 0002  cmp.w #2,%d0
        beq.w   .L3c426090                      | 3c426054  6700 003a
        .short  0xb07c, 0x0003                  | 3c426058  b07c 0003  cmp.w #3,%d0
        beq.w   .L3c426096                      | 3c42605c  6700 0038
        movea.l (0x14,%sp),%a0                  | 3c426060  206f 0014
        move.w  #255,(%a0)                      | 3c426064  30bc 00ff
.L3c426068:
        rts                                     | 3c426068  4e75
.L3c42606a:
        clr.w   (0xffff8040).w                  | 3c42606a  4278 8040
.L3c42606e:
        movea.l (0x14,%sp),%a0                  | 3c42606e  206f 0014
        move.b  (0xffff809b).w,%d0              | 3c426072  1038 809b
        clr.b   (0xffff80db).w                  | 3c426076  4238 80db
        clr.b   (0xffff80fb).w                  | 3c42607a  4238 80fb
        move.w  %d0,(%a0)                       | 3c42607e  3080
        movea.l (0xc,%sp),%a0                   | 3c426080  206f 000c
        move.l  (0xffff8014).w,(%a0)            | 3c426084  20b8 8014
        bra.s   .L3c426068                      | 3c426088  60de
.L3c42608a:
        clr.w   (0xffff8044).w                  | 3c42608a  4278 8044
        bra.s   .L3c42606e                      | 3c42608e  60de
.L3c426090:
        clr.w   (0xffff8048).w                  | 3c426090  4278 8048
        bra.s   .L3c42606e                      | 3c426094  60d8
.L3c426096:
        clr.w   (0xffff804c).w                  | 3c426096  4278 804c
        bra.s   .L3c42606e                      | 3c42609a  60d2

/* FIM_$FP_REX_DP_DIADIC(a, b, result, op, status) - 0x3C42609C: the
   double-precision operation op (0 .. 3: the words at 16#FFFF805C,
   16#FFFF8064, 16#FFFF8068, 16#FFFF8050) on a and b. */
        .section ".text.FIM_$FP_REX_DP_DIADIC","ax",@progbits
        .even
FIM_$FP_REX_DP_DIADIC:
        clr.b   (0xffff80db).w                  | 3c42609c  4238 80db
        clr.b   (0xffff80fb).w                  | 3c4260a0  4238 80fb
        movea.l (0x4,%sp),%a0                   | 3c4260a4  206f 0004
        move.l  (%a0)+,(0xffff800c).w           | 3c4260a8  21d8 800c
        move.l  (%a0),(0xffff8014).w            | 3c4260ac  21d0 8014
        movea.l (0x8,%sp),%a0                   | 3c4260b0  206f 0008
        move.l  (%a0)+,(0xffff840c).w           | 3c4260b4  21d8 840c
        move.l  (%a0),(0xffff8414).w            | 3c4260b8  21d0 8414
        movea.l (0x10,%sp),%a0                  | 3c4260bc  206f 0010
        move.w  (%a0),%d0                       | 3c4260c0  3010
        .short  0xb07c, 0x0000                  | 3c4260c2  b07c 0000  cmp.w #0,%d0
        beq.w   .L3c4260ec                      | 3c4260c6  6700 0024
        .short  0xb07c, 0x0001                  | 3c4260ca  b07c 0001  cmp.w #1,%d0
        beq.w   .L3c426110                      | 3c4260ce  6700 0040
        .short  0xb07c, 0x0002                  | 3c4260d2  b07c 0002  cmp.w #2,%d0
        beq.w   .L3c426116                      | 3c4260d6  6700 003e
        .short  0xb07c, 0x0003                  | 3c4260da  b07c 0003  cmp.w #3,%d0
        beq.w   .L3c42611c                      | 3c4260de  6700 003c
        movea.l (0x14,%sp),%a0                  | 3c4260e2  206f 0014
        move.w  #255,(%a0)                      | 3c4260e6  30bc 00ff
.L3c4260ea:
        rts                                     | 3c4260ea  4e75
.L3c4260ec:
        clr.w   (0xffff805c).w                  | 3c4260ec  4278 805c
.L3c4260f0:
        movea.l (0x14,%sp),%a0                  | 3c4260f0  206f 0014
        move.b  (0xffff809b).w,%d0              | 3c4260f4  1038 809b
        clr.b   (0xffff80db).w                  | 3c4260f8  4238 80db
        clr.b   (0xffff80fb).w                  | 3c4260fc  4238 80fb
        move.w  %d0,(%a0)                       | 3c426100  3080
        movea.l (0xc,%sp),%a0                   | 3c426102  206f 000c
        move.l  (0xffff8014).w,(%a0)+           | 3c426106  20f8 8014
        move.l  (0xffff8018).w,(%a0)            | 3c42610a  20b8 8018
        bra.s   .L3c4260ea                      | 3c42610e  60da
.L3c426110:
        clr.w   (0xffff8064).w                  | 3c426110  4278 8064
        bra.s   .L3c4260f0                      | 3c426114  60da
.L3c426116:
        clr.w   (0xffff8068).w                  | 3c426116  4278 8068
        bra.s   .L3c4260f0                      | 3c42611a  60d4
.L3c42611c:
        clr.w   (0xffff8050).w                  | 3c42611c  4278 8050
        bra.s   .L3c4260f0                      | 3c426120  60ce

/* FIM_$FP_REX_SP_MONADIC(a, result, op, status) - 0x3C426122: op 0 the
   operation at 16#FFFF8006 on a; 1 result = a; 2 result = a without its
   sign. */
        .section ".text.FIM_$FP_REX_SP_MONADIC","ax",@progbits
        .even
FIM_$FP_REX_SP_MONADIC:
        clr.b   (0xffff80db).w                  | 3c426122  4238 80db
        movea.l (0x4,%sp),%a0                   | 3c426126  206f 0004
        move.l  (%a0),(0xffff800c).w            | 3c42612a  21d0 800c
        movea.l (0xc,%sp),%a0                   | 3c42612e  206f 000c
        move.w  (%a0),%d0                       | 3c426132  3010
        .short  0xb07c, 0x0000                  | 3c426134  b07c 0000  cmp.w #0,%d0
        beq.w   .L3c426156                      | 3c426138  6700 001c
        .short  0xb07c, 0x0001                  | 3c42613c  b07c 0001  cmp.w #1,%d0
        beq.w   .L3c426176                      | 3c426140  6700 0034
        .short  0xb07c, 0x0002                  | 3c426144  b07c 0002  cmp.w #2,%d0
        beq.w   .L3c426188                      | 3c426148  6700 003e
        movea.l (0x10,%sp),%a0                  | 3c42614c  206f 0010
        move.w  #255,(%a0)                      | 3c426150  30bc 00ff
.L3c426154:
        rts                                     | 3c426154  4e75
.L3c426156:
        clr.b   (0xffff8006).w                  | 3c426156  4238 8006
        movea.l (0x10,%sp),%a0                  | 3c42615a  206f 0010
        move.b  (0xffff809b).w,%d0              | 3c42615e  1038 809b
        clr.b   (0xffff80db).w                  | 3c426162  4238 80db
        clr.b   (0xffff80fb).w                  | 3c426166  4238 80fb
        move.w  %d0,(%a0)                       | 3c42616a  3080
        movea.l (0x8,%sp),%a0                   | 3c42616c  206f 0008
        move.l  (0xffff8014).w,(%a0)            | 3c426170  20b8 8014
        bra.s   .L3c426154                      | 3c426174  60de
.L3c426176:
        movea.l (0x4,%sp),%a0                   | 3c426176  206f 0004
        movea.l (0x8,%sp),%a1                   | 3c42617a  226f 0008
        move.l  (%a0),(%a1)                     | 3c42617e  2290
        movea.l (0x10,%sp),%a0                  | 3c426180  206f 0010
        clr.w   (%a0)                           | 3c426184  4250
        bra.s   .L3c426154                      | 3c426186  60cc
.L3c426188:
        movea.l (0x4,%sp),%a0                   | 3c426188  206f 0004
        movea.l (0x8,%sp),%a1                   | 3c42618c  226f 0008
        move.l  (%a0),%d0                       | 3c426190  2010
        .short  0xc0bc, 0x7fff, 0xffff          | 3c426192  c0bc 7fff ffff  and.l #0x7fffffff,%d0
        move.l  %d0,(%a1)                       | 3c426198  2280
        movea.l (0x10,%sp),%a0                  | 3c42619a  206f 0010
        clr.w   (%a0)                           | 3c42619e  4250
        bra.s   .L3c426154                      | 3c4261a0  60b2

/* FIM_$FP_REX_DP_MONADIC(a, result, op, status) - 0x3C4261A2: op 0 the
   operation at 16#FFFF8002 on a; 1 result = a; 2 result = a without its
   sign. */
        .section ".text.FIM_$FP_REX_DP_MONADIC","ax",@progbits
        .even
FIM_$FP_REX_DP_MONADIC:
        clr.b   (0xffff80db).w                  | 3c4261a2  4238 80db
        movea.l (0x4,%sp),%a0                   | 3c4261a6  206f 0004
        move.l  (%a0)+,(0xffff800c).w           | 3c4261aa  21d8 800c
        move.l  (%a0),(0xffff8014).w            | 3c4261ae  21d0 8014
        movea.l (0xc,%sp),%a0                   | 3c4261b2  206f 000c
        move.w  (%a0),%d0                       | 3c4261b6  3010
        .short  0xb07c, 0x0000                  | 3c4261b8  b07c 0000  cmp.w #0,%d0
        beq.w   .L3c4261da                      | 3c4261bc  6700 001c
        .short  0xb07c, 0x0001                  | 3c4261c0  b07c 0001  cmp.w #1,%d0
        beq.w   .L3c4261fe                      | 3c4261c4  6700 0038
        .short  0xb07c, 0x0002                  | 3c4261c8  b07c 0002  cmp.w #2,%d0
        beq.w   .L3c426212                      | 3c4261cc  6700 0044
        movea.l (0x10,%sp),%a0                  | 3c4261d0  206f 0010
        move.w  #255,(%a0)                      | 3c4261d4  30bc 00ff
.L3c4261d8:
        rts                                     | 3c4261d8  4e75
.L3c4261da:
        clr.b   (0xffff8002).w                  | 3c4261da  4238 8002
        movea.l (0x10,%sp),%a0                  | 3c4261de  206f 0010
        move.b  (0xffff809b).w,%d0              | 3c4261e2  1038 809b
        clr.b   (0xffff80db).w                  | 3c4261e6  4238 80db
        clr.b   (0xffff80fb).w                  | 3c4261ea  4238 80fb
        move.w  %d0,(%a0)                       | 3c4261ee  3080
        movea.l (0x8,%sp),%a0                   | 3c4261f0  206f 0008
        move.l  (0xffff8014).w,(%a0)+           | 3c4261f4  20f8 8014
        move.l  (0xffff8018).w,(%a0)            | 3c4261f8  20b8 8018
        bra.s   .L3c4261d8                      | 3c4261fc  60da
.L3c4261fe:
        movea.l (0x4,%sp),%a0                   | 3c4261fe  206f 0004
        movea.l (0x8,%sp),%a1                   | 3c426202  226f 0008
        move.l  (%a0)+,(%a1)+                   | 3c426206  22d8
        move.l  (%a0),(%a1)                     | 3c426208  2290
        movea.l (0x10,%sp),%a0                  | 3c42620a  206f 0010
        clr.w   (%a0)                           | 3c42620e  4250
        bra.s   .L3c4261d8                      | 3c426210  60c6
.L3c426212:
        movea.l (0x4,%sp),%a0                   | 3c426212  206f 0004
        movea.l (0x8,%sp),%a1                   | 3c426216  226f 0008
        move.l  (%a0)+,%d0                      | 3c42621a  2018
        .short  0xc0bc, 0x7fff, 0xffff          | 3c42621c  c0bc 7fff ffff  and.l #0x7fffffff,%d0
        move.l  %d0,(%a1)+                      | 3c426222  22c0
        move.l  (%a0),(%a1)                     | 3c426224  2290
        movea.l (0x10,%sp),%a0                  | 3c426226  206f 0010
        clr.w   (%a0)                           | 3c42622a  4250
        bra.s   .L3c4261d8                      | 3c42622c  60aa

/* FIM_$FP_REX_SP_CVT(a, result, op, status) - 0x3C42622E: the
   conversion op of the single-precision a to a double-precision result
   (op 0, 1, 3: the bytes at 16#FFFF8005, 16#FFFF800D, 16#FFFF8015; op 3's
   arm is op 0's code again). */
        .section ".text.FIM_$FP_REX_SP_CVT","ax",@progbits
        .even
FIM_$FP_REX_SP_CVT:
        clr.b   (0xffff80db).w                  | 3c42622e  4238 80db
        movea.l (0x4,%sp),%a0                   | 3c426232  206f 0004
        move.l  (%a0),(0xffff800c).w            | 3c426236  21d0 800c
        movea.l (0xc,%sp),%a0                   | 3c42623a  206f 000c
        move.w  (%a0),%d0                       | 3c42623e  3010
        .short  0xb07c, 0x0000                  | 3c426240  b07c 0000  cmp.w #0,%d0
        beq.w   .L3c426262                      | 3c426244  6700 001c
        .short  0xb07c, 0x0001                  | 3c426248  b07c 0001  cmp.w #1,%d0
        beq.w   .L3c426286                      | 3c42624c  6700 0038
        .short  0xb07c, 0x0003                  | 3c426250  b07c 0003  cmp.w #3,%d0
        beq.w   .L3c42628c                      | 3c426254  6700 0036
        movea.l (0x10,%sp),%a0                  | 3c426258  206f 0010
        move.w  #255,(%a0)                      | 3c42625c  30bc 00ff
.L3c426260:
        rts                                     | 3c426260  4e75
.L3c426262:
        clr.b   (0xffff8005).w                  | 3c426262  4238 8005
.L3c426266:
        movea.l (0x10,%sp),%a0                  | 3c426266  206f 0010
        move.b  (0xffff809b).w,%d0              | 3c42626a  1038 809b
        clr.b   (0xffff80db).w                  | 3c42626e  4238 80db
        clr.b   (0xffff80fb).w                  | 3c426272  4238 80fb
        move.w  %d0,(%a0)                       | 3c426276  3080
        movea.l (0x8,%sp),%a0                   | 3c426278  206f 0008
        move.l  (0xffff8014).w,(%a0)+           | 3c42627c  20f8 8014
        move.l  (0xffff8018).w,(%a0)            | 3c426280  20b8 8018
        bra.s   .L3c426260                      | 3c426284  60da
.L3c426286:
        clr.b   (0xffff800d).w                  | 3c426286  4238 800d
        bra.s   .L3c426266                      | 3c42628a  60da
.L3c42628c:
        clr.b   (0xffff8015).w                  | 3c42628c  4238 8015
        movea.l (0x10,%sp),%a0                  | 3c426290  206f 0010
        move.b  (0xffff809b).w,%d0              | 3c426294  1038 809b
        clr.b   (0xffff80db).w                  | 3c426298  4238 80db
        clr.b   (0xffff80fb).w                  | 3c42629c  4238 80fb
        move.w  %d0,(%a0)                       | 3c4262a0  3080
        movea.l (0x8,%sp),%a0                   | 3c4262a2  206f 0008
        move.l  (0xffff8014).w,(%a0)+           | 3c4262a6  20f8 8014
        move.l  (0xffff8018).w,(%a0)            | 3c4262aa  20b8 8018
        bra.s   .L3c426260                      | 3c4262ae  60b0

/* FIM_$FP_REX_DP_CVT(a, result, op, status) - 0x3C4262B0: the
   conversion op of the double-precision a (op 0, 1: the bytes at
   16#FFFF8001, 16#FFFF8009, a double-precision result; op 2: the byte
   at 16#FFFF8011, a single-precision one). */
        .section ".text.FIM_$FP_REX_DP_CVT","ax",@progbits
        .even
FIM_$FP_REX_DP_CVT:
        clr.b   (0xffff80db).w                  | 3c4262b0  4238 80db
        movea.l (0x4,%sp),%a0                   | 3c4262b4  206f 0004
        move.l  (%a0)+,(0xffff800c).w           | 3c4262b8  21d8 800c
        move.l  (%a0),(0xffff8014).w            | 3c4262bc  21d0 8014
        movea.l (0xc,%sp),%a0                   | 3c4262c0  206f 000c
        move.w  (%a0),%d0                       | 3c4262c4  3010
        .short  0xb07c, 0x0000                  | 3c4262c6  b07c 0000  cmp.w #0,%d0
        beq.w   .L3c4262e8                      | 3c4262ca  6700 001c
        .short  0xb07c, 0x0001                  | 3c4262ce  b07c 0001  cmp.w #1,%d0
        beq.w   .L3c42630c                      | 3c4262d2  6700 0038
        .short  0xb07c, 0x0002                  | 3c4262d6  b07c 0002  cmp.w #2,%d0
        beq.w   .L3c426312                      | 3c4262da  6700 0036
        movea.l (0x10,%sp),%a0                  | 3c4262de  206f 0010
        move.w  #255,(%a0)                      | 3c4262e2  30bc 00ff
.L3c4262e6:
        rts                                     | 3c4262e6  4e75
.L3c4262e8:
        clr.b   (0xffff8001).w                  | 3c4262e8  4238 8001
.L3c4262ec:
        movea.l (0x10,%sp),%a0                  | 3c4262ec  206f 0010
        move.b  (0xffff809b).w,%d0              | 3c4262f0  1038 809b
        clr.b   (0xffff80db).w                  | 3c4262f4  4238 80db
        clr.b   (0xffff80fb).w                  | 3c4262f8  4238 80fb
        move.w  %d0,(%a0)                       | 3c4262fc  3080
        movea.l (0x8,%sp),%a0                   | 3c4262fe  206f 0008
        move.l  (0xffff8014).w,(%a0)+           | 3c426302  20f8 8014
        move.l  (0xffff8018).w,(%a0)            | 3c426306  20b8 8018
        bra.s   .L3c4262e6                      | 3c42630a  60da
.L3c42630c:
        clr.b   (0xffff8009).w                  | 3c42630c  4238 8009
        bra.s   .L3c4262ec                      | 3c426310  60da
.L3c426312:
        clr.b   (0xffff8011).w                  | 3c426312  4238 8011
        movea.l (0x10,%sp),%a0                  | 3c426316  206f 0010
        move.b  (0xffff809b).w,%d0              | 3c42631a  1038 809b
        clr.b   (0xffff80db).w                  | 3c42631e  4238 80db
        clr.b   (0xffff80fb).w                  | 3c426322  4238 80fb
        move.w  %d0,(%a0)                       | 3c426326  3080
        movea.l (0x8,%sp),%a0                   | 3c426328  206f 0008
        move.l  (0xffff8014).w,(%a0)            | 3c42632c  20b8 8014
        bra.s   .L3c4262e6                      | 3c426330  60b4
        .short  0                               | 3c426332  the segment's pad; FIM_WIRED starts at 0x3C426334

        .endif
