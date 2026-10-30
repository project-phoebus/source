|
| ec/m68k/ec2_wait_ecs.s - EC2_$WAIT_ECS, the per-process level-1
| eventcounts EC2_$WAIT blocks on
|
| The SAU2 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the
| image's 0x300 zero bytes.
|
| SAU2 map: "D E20F6C EC2_ASM size = 300" (WIRED_DATA, after PROC1_ASM),
| one symbol, EC2_$WAIT_ECS, at its start: 64 eventcounts of 12 bytes,
| indexed by process number from 1 (ec/ec.ins.pas).  All zero in the
| image; EC2_$INIT_S initialises them with EC_$INIT.
|
        .section ".text.EC2_$WAIT_ECS","ax",@progbits
        .balign 2

        .globl  EC2_$WAIT_ECS

EC2_$WAIT_ECS:                          | 0xE20F6C
        .space  64 * 12
