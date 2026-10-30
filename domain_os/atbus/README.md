# The ATBUS subsystem in Domain Pascal

The AT bus's interrupt routines and address translation, on the SAUs
whose map has the ATBUS_$ routines (the part `atbus_routines`,
`../base/config.ins.pas`: the SR10.2 SAU7..SAU9). Translated from the
SAU9 image; the SAU2 and SAU5 builds compile the module to an empty
object.

## Layout

The SAU9's map has two compilation units named ATBUS_.  The first, the
system bus's routines (SYSBUS_$INT .. SYSBUS_$INIT), is
`../sysbus/atbus_.pas`.  The second, the ATBUS_$ routines, is
`atbus.pas`, `module atbus_, wired_proc, wired_data;` (the map
segment's name), its whole body under `%if atbus_routines`:

| section | SAU9 segment | routines | attribute |
|---------|--------------|----------|-----------|
| WIRED_PROC | ATBUS_, 0x2CC bytes | ATBUS_$UNDEF_INT .. ATBUS_$XLATE_IOVA | none (the heading's) |
| OS_INIT_PROC | ATBUS_, 0x4C bytes | ATBUS_$INIT | `[section(os_init_proc, os_init_data)]` |
| WIRED_DATA | ATBUS_ data, 0xF8 bytes | ATBUS_$INTLEV_VEC, ATBUS_$INT_VEC and the module's tables | module variables |

The block (`atbus.pas` tables it): the three system bus levels'
interrupt ids (vectors 16#A1..16#A3), a longword nothing addresses (a
stand-in), each AT bus interrupt's select value and level, the map's
ATBUS_$INTLEV_VEC and ATBUS_$INT_VEC (read by no SAU9 routine; the
SAU7's and SAU8's ATBUS_$INT uses them), and the interrupt defined on
each level.  dpc lays it out at the image's offsets, with the image's
initial bytes.

## Routines and their fragments

All eight are compiled code.

| routine | fragment |
|---------|----------|
| ATBUS_$UNDEF_INT | `undef_int.pas` |
| ATBUS_$DEFINE_INT | `define_int.pas` |
| ATBUS_$ENABLE_DEVICE | `enable_device.pas` |
| ATBUS_$DISABLE_DEVICE | `disable_device.pas` |
| ATBUS_$DEVICE_INTERRUPTING | `device_interrupting.pas` |
| ATBUS_$CLEAR_PENDING | `clear_pending.pas` |
| ATBUS_$XLATE_IOVA | `xlate_iova.pas` |
| ATBUS_$INIT | `init.pas` |

## Insert files

- `atbus.ins.pas` (new): the AT bus manager's status, the counts and
  limits, the level types, the handler and vector entry types, the two
  map variables and the headings.  The headings of the seven routines
  IO_$BUS_EPV's entry 3 holds are the types of the bus vector's fields
  (`../io/io.ins.pas`); `../io/io.pas` fills the entry under
  `atbus_routines`.
- `../mmu/mmu.ins.pas` (extended): MMU_$IMR_COPY and MMU_IMR, the
  SAU9's interrupt mask register and its copy, with the two select
  fields.
- `../sysbus/sysbus.ins.pas` (extended): the SYSBUS_ headings the
  routines call.

## Open items

- TODO(sau): the SAU7's and SAU8's forms (`atbus.pas`): their own
  ATBUS_$INT and an interrupt controller pair; only ATBUS_$XLATE_IOVA
  and ATBUS_$UNDEF_INT are the SAU9's code there.
- The two ATBUS_ units have the same module name: a SAU9 layout must
  place two `ATBUS_` segments in WIRED_PROC and two in WIRED_DATA, the
  system bus's first.
