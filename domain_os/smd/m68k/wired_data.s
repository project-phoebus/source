/*
 * smd/m68k/wired_data.s - the data of the hand-written SMD_WIRED segment
 * (SAU2, SAU5, SAU9)
 *
 * The SAU2, SAU5 and SAU9 images have the same data here except in three
 * places, which test base/config.ins.pas's parts:
 *   gpu_driver         after MATROX_$BOARD_INSTALLED, the SAU5's map
 *                      symbols COLOR3_$CR_CONTENTS and
 *                      SMD_$GRAPHIC_DEVICE_ID and the SAU5 cursor body's
 *                      cells (0x78 bytes, to SMD_$BLINK_CURSOR_1 at
 *                      0x00E280C2); the SAU2's run is the word alone.
 *                      The maps: SMD_$GRAPHIC_DEVICE_ID and
 *                      COLOR3_$CR_CONTENTS are SAU5 and SAU6 symbols
 *                      only (SMD_$INIT reads the first: config.ins.pas's
 *                      gpu_driver); the SAU6's run is 0x62 bytes and the
 *                      SAU4's (no such symbols) 0x32, other forms, for
 *                      their own arms when those SAUs are built.
 *   two_display_units  SMD_$DISPLAY_COM is two 0x60-byte display
 *                      records on the SAU5 (0xC0 bytes, as the SAU6's;
 *                      the SAU4's is 0x1C0, another form), one on the
 *                      SAU2.
 *   display_devices    the SAU9's segment (`D 3C42A720 SMD_WIRED size =
 *                      4D8') is the data run from SMD_$CURSOR_TABLE
 *                      alone: no code, so no MATROX_$BOARD_INSTALLED;
 *                      SMD_$DISPLAY_COM is 0x300 bytes, zero (the
 *                      SAU7's segment has the same size); the US table
 *                      ends the segment, with no zero word after it.
 *                      The other bytes are the SAU2's.
 * The address and byte columns are the SAU2 image's, except on the lines
 * of the `.if' arms taken by the SAU5 alone, which carry the SAU5 image's
 * addresses.  Every other byte is the same on both; the pointer cells
 * are relocations, so their values (the SAU2's in the comments) follow
 * each SAU's layout.
 *
 * Byte gate (tools/asm_compare.py, `make check-asm'): the bytes are the
 * image's, the pointer cells relocations resolved against the image's
 * longwords.
 *
 * SAU2 map: "D E26F20 SMD_WIRED size = 5E0" (WIRED_DATA), 0x00E26F20..
 * 0x00E274FF, hand-written code and data (smd/README.md).  Its
 * code is in the other smd/sau2/*.s files (disp1_int.s,
 * cursor_thunks.s, blink_cursor_1.s, interrupt_init.s, scroll.s,
 * start_blt.s).  This file holds its data, the map's symbols:
 *
 *   0xE2722A  MATROX_$BOARD_INSTALLED  a word, zero (between the OR_CURSOR
 *                                      trampoline's two cells and
 *                                      SMD_$BLINK_CURSOR_1)
 *   0xE272C6  SMD_$CURSOR_TABLE        four 0x28-byte cursor patterns
 *                                      (a header of four words, then 16
 *                                      pattern words)
 *   0xE27366  SMD_$CURSOR_PTABLE       their four addresses
 *   0xE27376  SMD_$DISPLAY_COM         the one 0x60-byte display record
 *                                      (smd/smd_internal.ins.pas)
 *   0xE273D6  SMD_TIME_$COM            6 bytes (smd_time_com_t)
 *   0xE273DC  MNK_$KTT_PTRS            eight keyboard translation table
 *                                      addresses, the national tables in
 *                                      SMD_UTILS's data (smd/sau2/
 *                                      smd_utils.s)
 *   0xE273FC  MNK_$KTT_MAX             the word 7
 *   0xE273FE  SMD_$KTT                 the US table, 0x100 bytes
 *   0xE274FE  a zero word to the segment's end (GPU_ASM at 0xE27500)
 *
 * The code reaches these PC-relatively (`lea (0x18e,PC),A1' to
 * SMD_TIME_$COM + 2 at 0xE27248, `lea (0x128,PC),A0' to SMD_$DISPLAY_COM
 * at 0xE2724C) and the compiled code absolutely (`movea.l #0xe27376,A0',
 * `movea.l #0xe273dc,A2'; smd/smd.ins.pas, smd/smd_internal.ins.pas).
 * MATROX_$BOARD_INSTALLED is its own section, keyed by the map between
 * SMD_$OR_CURSOR's (cursor_thunks.s) and SMD_$BLINK_CURSOR_1's; the rest
 * is one section from SMD_$CURSOR_TABLE to the segment's end.
 *
 * SAU5 map: "D E27D78 SMD_WIRED size = 7C8" (WIRED_DATA).  Its code is in
 * smd/sau5/*.s (disp1_int.s, cursor_thunks.s, blink_cursor_1.s,
 * interrupt_init.s, scroll.s, start_blt.s; the code segment in
 * wired_proc.s).  The same two runs, keyed by the same symbols:
 *
 *   0xE28048  MATROX_$BOARD_INSTALLED, then COLOR3_$CR_CONTENTS
 *             (0xE2804C) and SMD_$GRAPHIC_DEVICE_ID (0xE2804E) and the
 *             cursor body's unnamed cells, up to SMD_$BLINK_CURSOR_1
 *   0xE282A6  SMD_$CURSOR_TABLE .. the segment's end (0xE28540): the
 *             SAU2's data with two display records (SMD_$DISPLAY_COM
 *             0xE28356, SMD_TIME_$COM 0xE28416, MNK_$KTT_PTRS 0xE2841C,
 *             MNK_$KTT_MAX 0xE2843C, SMD_$KTT 0xE2843E)
 *
 * The SAU5's cursor body (smd/sau5/wired_proc.s) reaches the first run's
 * cells at fixed displacements from the segment's base, SMD_$DISP2_INT
 * (0xE27D78; the +0x... offsets below), and the second run's
 * SMD_$CURSOR_TABLE (+0x52E) and unit 2's display record
 * (SMD_$DISPLAY_COM + 0x60, +0x63E): the data segment's sections are
 * laid out contiguously in the map's order.
 *
 * Not on the SAUs without the display driver (`display_driver',
 * base/config.ins.pas): the SAU3 map has no SMD_WIRED segment.
 */

        .include "base/config.inc"
        .if     display_driver

        .if !display_devices
        .section ".text.MATROX_$BOARD_INSTALLED","ax",@progbits
        .globl  MATROX_$BOARD_INSTALLED
MATROX_$BOARD_INSTALLED:                        /* e2722a */
        .word   0

        .if gpu_driver
        .globl  COLOR3_$CR_CONTENTS
        .globl  SMD_$GRAPHIC_DEVICE_ID

/* +0x2D2: the DN570 board's status bit 12, as the cursor body last
   sampled it. */
        .word   0                               /* sau5 e2804a */

/* +0x2D4: the DN570 board's control register as last written. */
COLOR3_$CR_CONTENTS:                            /* sau5 e2804c */
        .word   0

/* The graphics board's id word, which SMD_$INIT reads from the board
   (smd/smd.ins.pas). */
SMD_$GRAPHIC_DEVICE_ID:                         /* sau5 e2804e */
        .word   0

/* +0x2D8: the DN580 board's registers, saved around the cursor's
   drawing (0x40 bytes). */
        .space  0x40                            /* sau5 e28050 */

/* +0x318: the DN580 board's mode word, saved. */
        .word   0                               /* sau5 e28090 */

/* +0x31A: not referenced by the code. */
        .word   0, 0                            /* sau5 e28092 */

/* +0x31E: the DN6xx/DN550 controllers' cursor command block.  The erase
   form is its first 9 words, the draw form all 19; +0x320's high byte
   is the controller's byte at +0x9A, put in before each send.  The
   cursor body fills the zero words; the DN570's cursor commands use the
   same words from +0x324. */
        .word   0xf803, 0x02ff, 0x8000          /* sau5 e28096 */
        .word   0, 0, 0, 0                      /* sau5 e2809c: +0x324, +0x328 */
        .word   0, 0                            /* sau5 e280a4: +0x32C the pattern's width, height */
        .word   0xf700, 0x2e22, 0x2222, 0xa080  /* sau5 e280a8 */
        .word   0, 0x0400                       /* sau5 e280b0: +0x338 */
        .word   0, 0                            /* sau5 e280b4: +0x33C */
        .word   0, 0                            /* sau5 e280b8: +0x340 */

/* +0x344: the controllers' cursor position command, 3 words. */
        .word   0, 0, 0                         /* sau5 e280bc */
        .endif
        .endif

        .section ".text.SMD_$CURSOR_TABLE","ax",@progbits
        .globl  SMD_$CURSOR_TABLE
        .globl  SMD_$CURSOR_PTABLE
        .globl  SMD_$DISPLAY_COM
        .globl  SMD_TIME_$COM
        .globl  MNK_$KTT_PTRS
        .globl  MNK_$KTT_MAX
        .globl  SMD_$KTT

/* SMD_$CURSOR_TABLE: four 0x28-byte cursor patterns. */
SMD_$CURSOR_TABLE:                              /* e272c6 */
.Lcursor0:                                     /* e272c6: pattern 0 */
        .word   0x0009, 0x0010, 0x0001, 0x0002  /* e272c6 */
        .word   0xFF80, 0xFF80, 0xFF80, 0xFF80, 0xFF80, 0xFF80, 0xFF80, 0xFF80  /* e272ce */
        .word   0xFF80, 0xFF80, 0xFF80, 0xFF80, 0xFF80, 0xFF80, 0xFF80, 0xFF80  /* e272de */
.Lcursor1:                                     /* e272ee: pattern 1 */
        .word   0x0008, 0x0010, 0x0000, 0x000F  /* e272ee */
        .word   0x8000, 0xC000, 0xE000, 0xF000, 0xF800, 0xFC00, 0xFE00, 0xF000  /* e272f6 */
        .word   0xD800, 0x9800, 0x0C00, 0x0C00, 0x0600, 0x0600, 0x0300, 0x0300  /* e27306 */
.Lcursor2:                                     /* e27316: pattern 2 */
        .word   0x0008, 0x0010, 0x0007, 0x000F  /* e27316 */
        .word   0x0100, 0x0300, 0x0700, 0x0F00, 0x1B00, 0x3300, 0x6300, 0xFB00  /* e2731e */
        .word   0x1F00, 0x1B00, 0x3100, 0x3000, 0x6000, 0x6000, 0xC000, 0xC000  /* e2732e */
.Lcursor3:                                     /* e2733e: pattern 3 */
        .word   0x0010, 0x0010, 0x0007, 0x0007  /* e2733e */
        .word   0x07E0, 0x1FF8, 0x3C3C, 0x781E, 0x7C3E, 0xEE77, 0xC7E3, 0xC3C3  /* e27346 */
        .word   0xC3C3, 0xC7E3, 0xEE77, 0x7C3E, 0x781E, 0x3C3C, 0x1FF8, 0x07E0  /* e27356 */

/* SMD_$CURSOR_PTABLE: the four patterns' addresses. */
SMD_$CURSOR_PTABLE:                             /* e27366 */
        .long   .Lcursor0                       /* 00e272c6 */
        .long   .Lcursor1                       /* 00e272ee */
        .long   .Lcursor2                       /* 00e27316 */
        .long   .Lcursor3                       /* 00e2733e */

/* SMD_$DISPLAY_COM: the one 0x60-byte display record (the SAU5's: two,
   unit 1's and unit 2's; smd/smd_internal.ins.pas), zero in the image. */
SMD_$DISPLAY_COM:                               /* e27376 */
        .if two_display_units
        .space  0xc0                            /* sau5 e28356 */
        .elseif display_devices
        .space  0x300                           /* sau9 3c42a7d0 */
        .else
        .space  0x60
        .endif

/* SMD_TIME_$COM: 6 bytes, zero in the image. */
SMD_TIME_$COM:                                  /* e273d6 */
        .word   0, 0, 0

/* MNK_$KTT_PTRS: one keyboard translation table per keyboard type. */
MNK_$KTT_PTRS:                                  /* e273dc */
        .long   SMD_$KTT                        /* 0  00e273fe */
        .long   SMD_$GERMAN_KTT                 /* 1  00e8497e */
        .long   SMD_$FRENCH_KTT                 /* 2  00e84a7e */
        .long   SMD_$NORWEGIAN_KTT              /* 3  00e84b7e */
        .long   SMD_$SWEDISH_KTT                /* 4  00e84b7e (the same table) */
        .long   SMD_$UK_KTT                     /* 5  00e84c7e */
        .long   SMD_$KTT                        /* 6  00e273fe */
        .long   SMD_$SWISS_KTT                  /* 7  00e84d7e */

MNK_$KTT_MAX:                                   /* e273fc */
        .word   7

/* SMD_$KTT: the US table, 0x100 bytes, then a zero word to the segment's
   end (0xE27500, GPU_ASM). */
SMD_$KTT:                                       /* e273fe */
        .byte   0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F  /* e273fe */
        .byte   0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0xBA,0x1D,0x1E,0xBB  /* e2740e */
        .byte   0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,0xBF  /* e2741e */
        .byte   0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,0xFD  /* e2742e */
        .byte   0x40,0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,0x4F  /* e2743e */
        .byte   0x50,0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5A,0x7B,0xBE,0x7D,0x5E,0x5F  /* e2744e */
        .byte   0x60,0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6A,0x6B,0x6C,0x6D,0x6E,0x6F  /* e2745e */
        .byte   0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7A,0x5B,0xFC,0x5D,0x7E,0x7F  /* e2746e */
        .byte   0x90,0x81,0x82,0x83,0x84,0x85,0x86,0x87,0x88,0x89,0x8A,0x8B,0x8C,0x8D,0x8E,0x8F  /* e2747e */
        .byte   0xC8,0xC9,0xCA,0xCB,0xCC,0xCD,0xCE,0xCF,0xD8,0xD9,0xDA,0xDB,0xDC,0xDD,0xDE,0xDF  /* e2748e */
        .byte   0xB0,0xA1,0xA2,0xA3,0xA4,0xA5,0xA6,0xA7,0xA8,0xA9,0xAA,0xAB,0xAC,0xAD,0xAE,0xAF  /* e2749e */
        .byte   0xE8,0xE9,0xEA,0xEB,0xEC,0xED,0xEE,0xEF,0xF8,0xF9,0xFA,0xFB,0xBC,0xBD,0xFE,0xFF  /* e274ae */
        .byte   0xC0,0xC1,0xC2,0xC3,0xC4,0xC5,0xC6,0xC7,0x5C,0x7C,0x97,0x96,0x2F,0x91,0x92,0x93  /* e274be */
        .byte   0xD0,0xD1,0xD2,0xD3,0xD4,0xD5,0xD6,0xD7,0x5C,0x7C,0x98,0x96,0x3F,0x94,0x95,0xFF  /* e274ce */
        .byte   0xE0,0xE1,0xE2,0xE3,0xE4,0xE5,0xE6,0xE7,0xFF,0xB5,0xB6,0xB7,0xB8,0xB1,0xB2,0xB3  /* e274de */
        .byte   0xF0,0xF1,0xF2,0xF3,0xF4,0xF5,0xF6,0xF7,0x1C,0x7F,0x99,0x96,0x1F,0xB4,0x9E,0x9F  /* e274ee */
        .if !display_devices
        .word   0                               /* e274fe: to the segment's end */
        .endif

        .endif  /* display_driver */
