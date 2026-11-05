|
| cache/sau7/physical.s - CACHE_$ENABLE_PHYSICAL, CACHE_$DISABLE_PHYSICAL
| and CACHE_$FLUSH_PHYSICAL, the SAU7's physical cache
|
| The last 0x20 bytes of the SAU7 map's "D 3C428FF4 MMU_ASM size = 6B8"
| (0x3C42968C..0x3C4296AC), after CACHE_$FLUSH_VIRTUAL.  On a board with
| the physical cache (ROADRUNNER, mmu/sau7/mmu_asm.s) its control
| register is the byte at MMU + 0x200 and its tags are CACHE_TAGS:
| - CACHE_$ENABLE_PHYSICAL flushes the cache (CACHE_$FLUSH_PHYSICAL) and
|   writes 0xE4 to the control register;
| - CACHE_$DISABLE_PHYSICAL writes 0 to it;
| - CACHE_$FLUSH_PHYSICAL reads the word at CACHE_TAGS into D0, which
|   flushes the cache.
| None takes an argument (cache/cache.ins.pas).  A pad word ends the
| segment.
|
| Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau7 check-asm'):
| encodings identical to the image; address operands resolve to our
| objects.  The address and byte columns are the SAU7 image's.
|

        .section ".text.CACHE_$ENABLE_PHYSICAL","ax",@progbits
        .even

        .globl  CACHE_$ENABLE_PHYSICAL
        .globl  CACHE_$DISABLE_PHYSICAL
        .globl  CACHE_$FLUSH_PHYSICAL

CACHE_$ENABLE_PHYSICAL:
        bsr.s   CACHE_$FLUSH_PHYSICAL           | 3c42968c  6114
        move.b  #0xE4,MMU+0x200                 | 3c42968e  13fc 00e4 3fff b600
        rts                                     | 3c429696  4e75

CACHE_$DISABLE_PHYSICAL:
        move.b  #0,MMU+0x200                    | 3c429698  13fc 0000 3fff b600
        rts                                     | 3c4296a0  4e75

CACHE_$FLUSH_PHYSICAL:
        move.w  CACHE_TAGS,%d0                  | 3c4296a2  3039 3ff5 e000
        rts                                     | 3c4296a8  4e75

        .short  0                               | 3c4296aa  0000
