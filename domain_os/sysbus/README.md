# The SYSBUS subsystem in Domain Pascal

The system bus's interrupt routines and set-up.

## Layout

The map has no SYSBUS segment: the SYSBUS_ routines are in the map's
ATBUS_ code segment (WIRED_PROC), the ATBUS_ module, with its ATBUS_
data segment (WIRED_DATA).  ATBUS_'s module file is `atbus_.pas`,
here: `module atbus_, wired_proc, wired_data;` (its data are module
variables the routines share), the fragments included in map order.
It is where the per-SAU conditional compilation of the bus set-up goes.
Two forms (`../base/config.ins.pas`):

- with `sysbus_int_vec` (the SAU9's; SAU4, SAU6 and SAU9 have the
  part): SYSBUS_$INT .. SYSBUS_$INIT (0x320 bytes on the SAU9), the
  four device routines with `util_pic` (SAU9), and the block, the
  map's SYSBUS_$INT_VEC (0x80 bytes, zero); with `sysbus_vectors_90`
  (SAU4) the levels are 32, on the vectors 16#90..16#9F and
  16#F0..16#FF (0x160 bytes of code, a block of 0x100 bytes); with
  `sysbus_vectors_88` (SAU6) 32 levels on 16#88..16#9F and
  16#F0..16#F7, each with a second handler (0x1DC bytes of code, a
  block of 0x1E4 bytes: SYSBUS_$DUP_VEC, SYSBUS_$INT_VEC at +0x60 and
  the next free SYSBUS_$DUP_VEC entry, a word at +0x1E0);
- without it (the SAU2's): DISK_INTERRUPT, RING_INTERRUPT,
  SYSBUS_$INIT, SYSBUS_$DEFINE_INT (0x118 bytes) and a block of 0x2C
  bytes, no map symbol inside.

The SAU7..SAU9 have a second compilation unit named ATBUS_, the
ATBUS_$ routines: `../atbus/atbus.pas`.

| routine | fragment |
|---------|----------|
| SYSBUS_$INT | `int.pas`: `sysbus_int_vec` |
| SYSBUS_$UNDEF_INT | `undef_int.pas`: `sysbus_int_vec` |
| SYSBUS_$DEFINE_INT | `define_int.pas`: two arms; the SAU2's arm is the segment's last routine, its status cell ends the segment, headed with the three unread `val_param` parameters of IO_$BUS_EPV's define_int type (io/io.ins.pas) |
| SYSBUS_$ENABLE_DEVICE | `enable_device.pas`: `util_pic` |
| SYSBUS_$DISABLE_DEVICE | `disable_device.pas`: `util_pic` |
| SYSBUS_$DEVICE_INTERRUPTING | `device_interrupting.pas`: `util_pic` |
| SYSBUS_$CLEAR_PENDING | `clear_pending.pas`: `util_pic` |
| SYSBUS_$INIT | `init.pas`: two arms |
| DISK_INTERRUPT | `../disk/interrupt.pas`: without `sysbus_int_vec` |
| RING_INTERRUPT | `../ring/interrupt.pas`: without `sysbus_int_vec` |

All the routines are compiled code; every fragment carries
`[section(wired_proc, wired_data)]`, as kbd/reset.pas does for its
foreign module, which places them as the heading does.

The SAU2 block (`atbus_.pas` tables it): three 12-byte groups (do_io,
dcte, dinit) at +0x00, +0x10 and +0x20 for controller types 2 (ring), 1
(floppy) and 0 (Winchester), with longwords at +0x0C and +0x1C nothing
addresses (stand-ins, the TODO(pascal) in `atbus_.pas`; three 12-byte
records 8-aligned from the block would give the same offsets).  The
do_io fields are `io/io.ins.pas`'s io_$do_io_t.  dpc lays them out at
the image's offsets.

`tools/pascal_check.sh` finds `atbus_.pas` by its module heading.

## Insert files

- `sysbus.ins.pas`: the two statuses, the levels' constants and type,
  the handler and vector entry types, the utility interrupt
  controller's registers (UTIL_PIC, `[device]`) and the two registers
  of UTIL_PIO that SYSBUS_$INIT writes, SYSBUS_$INT_VEC, and the eight
  headings.
- `io/io.ins.pas`: `dcte_t`, `dcte_ptr_t`, io_vector_ring/io_vector_disk,
  `io_$dcte_list`, IO_$TRAP, `io_$int_id_t` and the bus vector's types.
  `io/io.pas` fills IO_$BUS_EPV's entry 4 with the SYSBUS_ routines the
  SAU has.
- `disk/disk.ins.pas`, `ring/ring.ins.pas`: the headings of
  DISK_INTERRUPT and RING_INTERRUPT (no parameters), whose addresses
  the SAU2's SYSBUS_$INIT passes to IO_$TRAP.

## The SAU3

The SAU3's ATBUS_ segment is RING_INTERRUPT, SYSBUS_$INIT and
SYSBUS_$DEFINE_INT (0x84 bytes), the block the SAU2's (0x2C bytes).
Without `winchester_config` there is no DISK_INTERRUPT, and SYSBUS_$INIT
traps the ring's vector and keeps only the ring's DCTE (`init.pas`);
SYSBUS_$DEFINE_INT and RING_INTERRUPT are the SAU2's.

## The SAU6

The SAU6's SYSBUS_$INT_VEC entries are 12 bytes, the handler, its
argument and the entry of SYSBUS_$DUP_VEC holding the level's second
handler.  SYSBUS_$DEFINE_INT gives a level whose handler is defined the
new one as its second, in the next free entry of SYSBUS_$DUP_VEC (eight
entries; the count is not checked); SYSBUS_$INT calls the second
handler when the first returns false.  The second range of vectors
starts at level 23, as SYSBUS_$INT's and SYSBUS_$DEFINE_INT's
expression has it on the SAU4: 16#F0 and 16#9F are both level 23.
SYSBUS_$UNDEF_INT is the SAU4's and SAU9's code.

## Open items

- TODO(pascal): SYSBUS_$INT's 4 frame bytes on the SAU9 (`int.pas`).
- TODO(pascal): the SAU2 block's two longwords nothing addresses
  (`atbus_.pas`).
- The SAU9's routines take the id's vector into an `integer` local and
  compare it signed, where io_$int_id_t's vector is a pinteger (the
  ATBUS_$ routines compare it unsigned); the local gives the image's
  signed compares on either field type.
- The purpose of UTIL_PIO's two registers (16#10 at +0x4, 16#CF at
  +0x8) is not known.
