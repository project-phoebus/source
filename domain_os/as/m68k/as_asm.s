/*
 * as/m68k/as_asm.s - the AS_ASM data segment: AS_$INFO and its neighbours
 *
 * The SAU2, SAU3 and SAU5 images have the same data here; the address and
 * byte columns below are the SAU2 image's.  The SAU7's and SAU9's
 * address space is another layout (`large_address_space',
 * base/config.ins.pas: the global and private regions near 0x3B400000,
 * PROT 0x3BFC0000): the same record and cells, its own values (SAU9 map:
 * "D 3C42FDEC AS_ASM size = 64").  The SAU8's is its default layout
 * (`run_time_layout': global A at 0x03200000, PROT 0x039C0000; SAU8 map:
 * "D 3C2DBB0 AS_ASM size = 64"), checked by assembling with `m68k-elf-as
 * -m68020 -m68881' against the image's bytes (all but the PROT cell).
 *
 * Byte gate (tools/asm_compare.py, `make check-asm'): the
 * bytes are the image's.
 *
 * SAU2 map: "D E2B914 AS_ASM size = 64" (WIRED_DATA), 0x00E2B914..
 * 0x00E2B977, PROC2_WIRED_ASM following at 0xE2B978.  A hand-written
 * block (the `_ASM' segment name; as/as.pas: no AS module has a data
 * segment).  Its symbols, all the map's:
 *
 *   0xE2B914  AS_$INFO                 the 0x5C-byte layout record
 *   0xE2B918  AS_$GLOBAL_A             +0x04
 *   0xE2B928  AS_$PRIVATE              +0x14
 *   0xE2B92C  AS_$STACK_FILE_LOW       +0x18
 *   0xE2B930  AS_$CR_REC               +0x1C
 *   0xE2B948  AS_$STACK_LOW            +0x34
 *   0xE2B950  AS_$STACK_HIGH           +0x3C
 *   0xE2B954  AS_$STACK_OFFSET         +0x40
 *   0xE2B960  AS_$INIT_STACK_FILE_SIZE +0x4C
 *   0xE2B96C  AS_$CR_REC_FILE_SIZE     +0x58
 *   0xE2B970  AS_$INFO_SIZE            a word, 0x5C (AS_$GET_INFO
 *                                      0xE583C4 reads it)
 *   0xE2B972  AS_$PROTECTION           a longword, 0x00CC0000 (EC2_$WAIT
 *                                      `cmp.l (0x00e2b972).l,D6' 0xE424C2):
 *                                      the address of the map's absolute
 *                                      PROT (`CC0000 PROT'), a cell of the
 *                                      image's RELOC fixup table, so it is
 *                                      written as the symbol
 *                                      (arch/m68k/sau2/iodefs.s)
 *   0xE2B976  two zero bytes to the segment's end
 *
 * The values are the 68010 layout; AS_$INIT rewrites the 68020 fields at
 * run time (as/as.ins.pas).  Field names other than the map's are
 * as/as.ins.pas's as_$info_t.  (`gsk read 0xe2b914 0x64'.)
 */

        .include "base/config.inc"

        .section ".text.AS_$INFO","ax",@progbits

        .globl  AS_$INFO
        .globl  AS_$GLOBAL_A
        .globl  AS_$PRIVATE
        .globl  AS_$STACK_FILE_LOW
        .globl  AS_$CR_REC
        .globl  AS_$STACK_LOW
        .globl  AS_$STACK_HIGH
        .globl  AS_$STACK_OFFSET
        .globl  AS_$INIT_STACK_FILE_SIZE
        .globl  AS_$CR_REC_FILE_SIZE
        .globl  AS_$INFO_SIZE
        .globl  AS_$PROTECTION

AS_$INFO:                                       /* e2b914 */
        .if large_address_space
        /* the SAU7's and SAU9's address space (sau9 0x3C42FDEC) */
        .long   0x00020000                      /* +0x00 */
AS_$GLOBAL_A:
        .long   0x3B400000, 0x00800000          /* +0x04 base, size */
        .long   0x3B400000, 0x00800000          /* +0x0C */
AS_$PRIVATE:
        .long   0x00008000                      /* +0x14 */
AS_$STACK_FILE_LOW:
        .long   0x3B380000                      /* +0x18 */
AS_$CR_REC:
        .long   0x3B3D0000, 0x00008000          /* +0x1C */
        .long   0x3B3D8000, 0x00028000          /* +0x24 cr_rec_end */
        .long   0x3B380000, 0x00008000          /* +0x2C stack_file_high */
AS_$STACK_LOW:
        .long   0x3B388000, 0x00040000          /* +0x34 */
AS_$STACK_HIGH:
        .long   0x3B3C8000                      /* +0x3C */
AS_$STACK_OFFSET:
        .long   0x00048000, 0x3B3C8000          /* +0x40, +0x44 */
        .long   0x00008000                      /* +0x48 */
AS_$INIT_STACK_FILE_SIZE:
        .long   0x00048000                      /* +0x4C */
        .long   0x3B3D8000, 0x00000004          /* +0x50 cr_rec_file, +0x54 */
AS_$CR_REC_FILE_SIZE:
        .long   0x00030000                      /* +0x58 */
        .elseif run_time_layout
        /* the SAU8's default layout (sau8 0x3C2DBB0); AS_$INIT moves it
           to the PMMU's */
        .long   0x00020000                      /* +0x00 */
AS_$GLOBAL_A:
        .long   0x03200000, 0x00600000          /* +0x04 base, size */
        .long   0x03200000, 0x00600000          /* +0x0C */
AS_$PRIVATE:
        .long   0x00008000                      /* +0x14 */
AS_$STACK_FILE_LOW:
        .long   0x03180000                      /* +0x18 */
AS_$CR_REC:
        .long   0x031D0000, 0x00008000          /* +0x1C */
        .long   0x031D8000, 0x00028000          /* +0x24 cr_rec_end */
        .long   0x03180000, 0x00008000          /* +0x2C stack_file_high */
AS_$STACK_LOW:
        .long   0x03188000, 0x00040000          /* +0x34 */
AS_$STACK_HIGH:
        .long   0x031C8000                      /* +0x3C */
AS_$STACK_OFFSET:
        .long   0x00048000, 0x031C8000          /* +0x40, +0x44 */
        .long   0x00008000                      /* +0x48 */
AS_$INIT_STACK_FILE_SIZE:
        .long   0x00048000                      /* +0x4C */
        .long   0x031D8000, 0x00000004          /* +0x50 cr_rec_file, +0x54 */
AS_$CR_REC_FILE_SIZE:
        .long   0x00030000                      /* +0x58 */
        .else
        .long   0x00020000                      /* +0x00 */
AS_$GLOBAL_A:                                   /* e2b918 */
        .long   0x009C0000, 0x00300000          /* +0x04 base, size */
        .long   0x009C0000, 0x00300000          /* +0x0C */
AS_$PRIVATE:                                    /* e2b928 */
        .long   0x00008000                      /* +0x14 */
AS_$STACK_FILE_LOW:                             /* e2b92c */
        .long   0x00940000                      /* +0x18 */
AS_$CR_REC:                                     /* e2b930 */
        .long   0x00990000, 0x00008000          /* +0x1C */
        .long   0x00998000, 0x00028000          /* +0x24 cr_rec_end */
        .long   0x00940000, 0x00008000          /* +0x2C stack_file_high */
AS_$STACK_LOW:                                  /* e2b948 */
        .long   0x00948000, 0x00040000          /* +0x34 */
AS_$STACK_HIGH:                                 /* e2b950 */
        .long   0x00988000                      /* +0x3C */
AS_$STACK_OFFSET:                               /* e2b954 */
        .long   0x00048000, 0x00988000          /* +0x40, +0x44 */
        .long   0x00008000                      /* +0x48 */
AS_$INIT_STACK_FILE_SIZE:                       /* e2b960 */
        .long   0x00048000                      /* +0x4C */
        .long   0x00998000, 0x00000004          /* +0x50 cr_rec_file, +0x54 */
AS_$CR_REC_FILE_SIZE:                           /* e2b96c */
        .long   0x00030000                      /* +0x58 */
        .endif
AS_$INFO_SIZE:                                  /* e2b970 */
        .word   0x005C
AS_$PROTECTION:                                 /* e2b972 */
        .long   PROT                            /* 00cc0000, a RELOC cell */
        .word   0                               /* e2b976: to the segment's end */
