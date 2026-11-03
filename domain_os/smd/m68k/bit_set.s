/*
 * smd/m68k/bit_set.s - SMD_$BIT_SET (hand-written assembly)
 *
 * The SAU2 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Original address: 0x00E15D12, 12 bytes.
 *
 * A three-instruction test-and-set thunk: no link/unlk, the argument is read
 * straight off the stack at (0x4,SP), and the result is a Domain boolean in
 * the low byte of D0.  `bset` is an indivisible read-modify-write on the
 * 68000 bus, which is the whole point of the routine.
 *
 * Entry:
 *   (0x4,SP)  uint8_t *byte_ptr
 *
 * Exit:
 *   D0.b  0xFF when bit 7 was clear before the call, 0x00 when it was set.
 *
 * Transcribed instruction for instruction:
 *   00e15d12    movea.l (0x4,SP),A0
 *   00e15d16    bset.b #0x7,(A0)
 *   00e15d1a    seq D0b
 *   00e15d1c    rts
 *
 * Not on the SAUs whose driver drives its displays through device
 * descriptors (`display_devices', base/config.ins.pas): the SAU7..SAU9
 * maps have no SMD_$BIT_SET.
 *
 * Not on the SAUs without the display driver (`display_driver',
 * base/config.ins.pas): the SAU3 map has no SMD_$BIT_SET.
 */

        .include "base/config.inc"
        .if     display_driver
        .if     !display_devices

        .section ".text.SMD_$BIT_SET","ax",@progbits
        .globl  SMD_$BIT_SET

SMD_$BIT_SET:
        movea.l 0x4(%sp),%a0            /* 00e15d12                     */
        bset.b  #0x7,(%a0)              /* 00e15d16: Z = old bit 7 == 0 */
        seq     %d0                     /* 00e15d1a: D0.b = 0xFF if Z   */
        rts                             /* 00e15d1c                     */

        .endif

        .endif  /* display_driver */
