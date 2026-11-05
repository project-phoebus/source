/*
 * fim/m68k/cold_bus_err.s - FIM_$COLD_BUS_ERR, the bus error vector while
 * the kernel initialises (m68k/SAU2, SAU5)
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Transcribed from the SAU2 image, 0x00E35004..0x00E35027 (36 bytes), the
 * whole map segment `D E35004 FIM_WIRED size = 24' (symbol
 * FIM_$COLD_BUS_ERR) inside OS_INIT_DATA.  Section .text.FIM_$COLD_BUS_ERR,
 * ordered by the map symbol.
 *
 * Image bytes (gsk read 0xE35004 0x24):
 *   e35004  4ab9 00e2 18cc 6706 4ef9 00e2 18ca 487a
 *   e35014  000c 486f 0004 4ef9 00e2 13a4 0012 0034
 *   e35024  000a 3000
 *
 * Installed as vector 2 by os_$install_vectors from BOOT_INFO_TABLE
 * (index 0x39), until OS_$INIT installs FIM_$BUS_ERR.  FIM_$BUILD_DF
 * compares vector 2 with this address to tell a fault during
 * initialisation from one in a running kernel.  If BUS_ERROR_SWITCH
 * (the operand of JMP_TO_BUS_ERR, fim/m68k/bus_err.s) is armed, the
 * fault goes there (io_$probe's recovery); otherwise to FIM_$COM with
 * the exception frame and the inline fault descriptor
 * (fim_fault_desc_t): status 0x00120034, signal 0x000A, class 0x3000
 * (FIM_FAULT_CLASS_ACCESS).  0x00120034 is "unexpected bus error during
 * system initialization" (stcodes 10.2).
 *
 * The SAU6's reads the MMU's word at +0xE first (`mmu_status_bit_6';
 * `D 7803F004 FIM_WIRED size = 2C': 6 bytes more and the rounding).
 *
 * Byte gate (tools/asm_compare.py): identical to the image modulo
 * relocations.
 */

        .include "base/config.inc"

        .extern BUS_ERROR_SWITCH        /* fim/m68k/bus_err.s, map 0xE218CC */
        .extern JMP_TO_BUS_ERR          /* fim/m68k/bus_err.s, image 0xE218CA */
        .extern FIM_$COM                /* fim/m68k/com.s, map 0xE213A4 */
        .if mmu_status_bit_6
        .extern MMU                     /* I/O definitions */
        .endif

        .section ".text.FIM_$COLD_BUS_ERR","ax",@progbits
        .even

        .global FIM_$COLD_BUS_ERR
FIM_$COLD_BUS_ERR:
        .if mmu_status_bit_6
        tst.w   (MMU+0xe).l                     /* sau6 7803f004  4a79 7fff b40e */
        .endif
        tst.l   (BUS_ERROR_SWITCH).l            /* e35004  4ab9 00e2 18cc */
        beq.b   .Lcbe_com                       /* e3500a  6706 */
        jmp     (JMP_TO_BUS_ERR).l              /* e3500c  4ef9 00e2 18ca */
.Lcbe_com:
        pea     (.Lcbe_desc,%pc)                /* e35012  487a 000c: &descriptor */
        pea     (4,%sp)                         /* e35016  486f 0004: &exception frame */
        jmp     (FIM_$COM).l                    /* e3501a  4ef9 00e2 13a4 */
.Lcbe_desc:
        .long   0x00120034                      /* e35020  status */
        .short  0x000A                          /* e35024  signal */
        .short  0x3000                          /* e35026  class */
        .if mmu_status_bit_6
        .short  0                               /* sau6 7803f02e  the segment rounded to a longword */
        .endif
