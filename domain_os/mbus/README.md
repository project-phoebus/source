# The MBUS subsystem in Domain Pascal

The Multibus interrupt vector and its set-up, on the SAUs whose kernel
has a Multibus (the part `mbus_bus`, `../base/config.ins.pas`: the
SR10.2 SAU3..SAU6).  Translated from the SAU5 image, with the SAU3's
polled adapter as conditional arms; the SAU2 build compiles the module
to an empty object.

## Layout

One module, `mbus.pas`, `module mbus_, wired_proc, wired_data;` (the map
segment's name), its whole body under `%if mbus_bus`:

| section | SAU5 segment | routines | attribute |
|---------|--------------|----------|-----------|
| WIRED_PROC | MBUS_, 0x70 bytes (SAU3 0xDC) | MBUS_$UNDEF_INT, MBUS_$DEFINE_INT, MBUS_$INT (`mbus_polled_adapter`) | none (the heading's) |
| OS_INIT_PROC | MBUS_, 0x74 bytes (SAU3 0x88) | MBUS_$INIT | `[section(os_init_proc, os_init_data)]` |
| WIRED_DATA | MBUS_ data, 0x84 bytes | MBUS_$INT_VEC, MBUS_$HIGH_OK, MBUS_$PRESENT | module variables (defined) |

MBUS_$ENABLE_DEV and MBUS_$DISABLE_DEV are in the map's VME_ segment:
the VME_ module (`../vme/vme.pas`) includes their fragments from this
directory.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| MBUS_$UNDEF_INT | `undef_int.pas` |
| MBUS_$DEFINE_INT | `define_int.pas` |
| MBUS_$INT | `int.pas` (`mbus_polled_adapter`) |
| MBUS_$INIT | `init.pas` |
| MBUS_$ENABLE_DEV | `enable_dev.pas` (included by `../vme/vme.pas`) |
| MBUS_$DISABLE_DEV | `disable_dev.pas` (included by `../vme/vme.pas`) |

`mbus.ins.pas` holds the status constant, the vector's types, the
adapter's register record (`mbus_$ctl_t`, PBU_CTL's), the module's
variables and MBUS_$UNDEF_INT's heading.  The headings of the four
routines IO_$BUS_EPV's entry 2 holds (MBUS_$INIT, MBUS_$DEFINE_INT,
MBUS_$ENABLE_DEV, MBUS_$DISABLE_DEV) are io/io.ins.pas's (the bus
vector's field types); a temporary copy is in `mbus.ins.pas` until the
two SAU5 translation groups' work is merged.

## The SAU3

The SAU3's adapter is polled (`mbus_polled_adapter`,
`../base/config.ins.pas`): MBUS_$INIT installs MBUS_$INT for the
level-4 autovector (16#1C) with IO_$TRAP and gives levels 0..7
MBUS_$UNDEF_INT; MBUS_$INT reads the register at +2 once and takes the
first level from 7 down whose bit and pending bit (eight above) are
both set.  MBUS_$HIGH_OK is bit 5 of the probed register, the first
register gets the probed value with 16#293, the third is not written.
MBUS_$UNDEF_INT and MBUS_$DEFINE_INT are the SAU5's code; the data
block is the same 0x84 bytes.

## Open items

- TODO(sau): MBUS_$INT's and MBUS_$INIT's SAU4 and SAU6 forms,
  MBUS_$DEFINE_INT's SAU6 form.
- TODO(pascal): the `integer32` transfer on the status constant, for
  dpc (mbus.ins.pas).
- MBUS_$INIT sets only levels 0..6 to MBUS_$UNDEF_INT; levels 7..15 keep
  a nil handler until defined (init.pas).
