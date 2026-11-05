|
| fim/m68k/wired_data.s - the data run of the hand-written FIM_WIRED
| segment: PARITY_$INFO, MISS_STATUS, PENDING_TRACE_FAULTS and the
| per-address-space tables FIM_$QUIT_EC, FIM_$QUIT_VALUE, FIM_$TRACE_STS,
| FIM_$QUIT_INH and FIM_$DELIV_EC
|
| The SAU2, SAU3 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): every byte is
| compared with the image, every pointer is a relocation resolved
| against the image's longword.
|
| SAU2 map: "D E21890 FIM_WIRED size = 1074", the run 0xE21FE6..0xE2277C
| between FIM_$PARITY_TRAP (fim/m68k/parity_trap.s) and
| FIM_$GET_USER_SR_PTR (fim/m68k/get_user_sr_ptr.s).  Every object is a
| map symbol; the tables have one element per address space, 58 (0..57,
| indexed by PROC1_$AS_ID), each the distance to the next symbol:
|
|   0xE21FE6  PARITY_$INFO            0x14  the parity error record
|                                           (parity/parity.ins.pas; its
|                                           +0x2 check flag, +0xC VA, +0x10
|                                           status, +0x12 data are
|                                           FIM_$PARITY_TRAP's), zero
|   0xE21FFA  MISS_STATUS             4     zero
|   0xE21FFE  PENDING_TRACE_FAULTS    4     zero
|   0xE22002  FIM_$QUIT_EC            58 * 12  eventcounts: value 0, the
|                                           waiter list empty (head = tail
|                                           = the eventcount itself)
|   0xE222BA  FIM_$QUIT_VALUE         58 * 4   zero
|   0xE223A2  FIM_$TRACE_STS          58 * 4   zero
|   0xE2248A  FIM_$QUIT_INH           58 * 1   0xFF each
|   0xE224C4  FIM_$DELIV_EC           58 * 12  eventcounts, as FIM_$QUIT_EC
|
| The C called the run FIM_$WIRED_DATA; the hand-written users now name
| these symbols.
|
| With `parity_cache_check' (the SAU7) the parity record is 0x16 bytes,
| its +0x14 word err_longword (parity/parity.ins.pas), and every object
| after it two bytes further on (SAU7 map: PARITY_$INFO 0x3C42722C,
| MISS_STATUS 0x3C427242).
|
| The SAUs whose memory corrects its errors (no `memory_parity',
| base/config.ins.pas) have no parity record: the SAU4's run starts with
| MISS_STATUS (0xF824278, after FIM_$ECCU_TRAP's two status words), the
| SAU6's at 0x780248B8 after FIM_$SPUR_CNT, the rest laid out as above.
|
        .include "base/config.inc"

        .if !memory_parity
        .section ".text.MISS_STATUS","ax",@progbits
        .else
        .section ".text.PARITY_$INFO","ax",@progbits
        .endif
        .balign 2

        .if memory_parity
        .globl  PARITY_$INFO
        .endif
        .globl  MISS_STATUS
        .globl  PENDING_TRACE_FAULTS
        .globl  FIM_$QUIT_EC
        .globl  FIM_$QUIT_VALUE
        .globl  FIM_$TRACE_STS
        .globl  FIM_$QUIT_INH
        .globl  FIM_$DELIV_EC

| N eventcounts at LABEL, each value 0 with its waiter list empty.
        .macro  empty_ecs label, n
        .set    ecn, 0
        .rept   \n
        .long   0, \label + ecn * 12, \label + ecn * 12
        .set    ecn, ecn + 1
        .endr
        .endm

        .if memory_parity
PARITY_$INFO:                           | 0xE21FE6
        .if parity_cache_check
        .space  0x16                    | sau7 0x3C42722C: + err_longword
        .else
        .space  0x14
        .endif
        .endif
MISS_STATUS:                            | 0xE21FFA
        .long   0
PENDING_TRACE_FAULTS:                   | 0xE21FFE
        .long   0
FIM_$QUIT_EC:                           | 0xE22002
        empty_ecs FIM_$QUIT_EC, 58
FIM_$QUIT_VALUE:                        | 0xE222BA
        .space  58 * 4
FIM_$TRACE_STS:                         | 0xE223A2
        .space  58 * 4
FIM_$QUIT_INH:                          | 0xE2248A
        .fill   58, 1, 0xFF
FIM_$DELIV_EC:                          | 0xE224C4
        empty_ecs FIM_$DELIV_EC, 58
