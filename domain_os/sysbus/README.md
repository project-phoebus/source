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
  map's SYSBUS_$INT_VEC (0x80 bytes, zero);
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

## Open items

- TODO(sau): the SAU3's, SAU4's and SAU6's forms (`atbus_.pas`,
  `int.pas`, `define_int.pas`, `init.pas`).
- TODO(pascal): the SAU2 block's two longwords nothing addresses
  (`atbus_.pas`).
- The SAU9's routines take the id's vector into an `integer` local and
  compare it signed, where io_$int_id_t's vector is a pinteger (the
  ATBUS_$ routines compare it unsigned); the local gives the image's
  signed compares on either field type.
- The purpose of UTIL_PIO's two registers (16#10 at +0x4, 16#CF at
  +0x8) is not known.
