|
| ml/m68k/lock_data.s - LOCK_BYTE, LOCK_$EVENT_LISTS and the PROC1_ASM
| status cells after them
|
| The SAU2 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): every
| byte is compared with the image, every pointer is a relocation resolved
| against the image's longword.
|
| SAU2 map: "D E1EAC8 PROC1_ASM size = 24A4", 0xE20BC4..0xE20DF8, between
| ML_$SPIN_UNLOCK (ml/m68k/spin_unlock.s) and ML_$EXCLUSION_START
| (ml/m68k/exclusion.s):
|   0xE20BC4  LOCK_BYTE           32 bytes, one per lock, zero; ML_$LOCK
|                                 and ML_$UNLOCK reach it with `lea
|                                 (d,PC)' and index it by the lock
|   0xE20BE4  LOCK_$EVENT_LISTS   32 * 16 bytes: per lock an eventcount
|                                 (value 0, waiter list empty: head = tail
|                                 = the eventcount itself) and its waiter
|                                 count (+0xC, 0); ML_$LOCK reaches entry
|                                 n as LOCK_BYTE + 0x20 + 16 * n
|   0xE20DE4  five status longwords, no map symbol (stcode.db.10.2 texts):
|             0xE20DE4  0x000A0002  illegal lock (Illegal_lock_err; the
|                                   lock crash stub's `pea' 0xE20B56)
|             0xE20DE8  0x000A0007  bad atomic operation
|                                   (Bad_atomic_operation_err;
|                                   atomic_op_error's `pea' 0xE209EE)
|             0xE20DEC  0x000A000B  ready list is out of order (not
|                                   referenced in the image)
|             0xE20DF0  0x00100013  interrupt stack error (not
|                                   referenced in the image)
|             0xE20DF4  0x000A000C  bad deferred interrupt queue (DI_$ENQ's
|                                   `pea' 0xE209B2, as Illegal_lock_err+0x10)
|
        .section ".text.LOCK_BYTE","ax",@progbits
        .balign 2

        .globl  LOCK_BYTE
        .globl  LOCK_$EVENT_LISTS
        .globl  Illegal_lock_err
        .globl  Bad_atomic_operation_err

LOCK_BYTE:                              | 0xE20BC4
        .space  32

LOCK_$EVENT_LISTS:                      | 0xE20BE4
        .set    lockn, 0
        .rept   32
        .long   0                       | value
        .long   LOCK_$EVENT_LISTS + lockn * 16  | waiter list head
        .long   LOCK_$EVENT_LISTS + lockn * 16  | waiter list tail
        .long   0                       | waiter count
        .set    lockn, lockn + 1
        .endr

Illegal_lock_err:                       | 0xE20DE4
        .long   0x000A0002
Bad_atomic_operation_err:               | 0xE20DE8
        .long   0x000A0007
        .long   0x000A000B              | 0xE20DEC
        .long   0x00100013              | 0xE20DF0
        .long   0x000A000C              | 0xE20DF4
