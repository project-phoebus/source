# The SIO6509 subsystem in Domain Pascal

The 6509 console serial controller driver.

## Layout

No module of its own.  The map has no SIO6509 segment: the five compiled
routines lie in three code segments of the SIO_IO module, beside the
2681 driver's (`sio2681/`), and the two hand-written objects in SIO_INT:

| section      | segment | SIO6509 routines | attribute |
|--------------|---------|------------------|-----------|
| WIRED_PROC   | SIO_IO, 0x69C bytes | SIO6509_$RCV, SIO6509_$XMIT (after SIO2681_$INT .. _$XMIT) | `[section(wired_proc, wired_data)]` |
| OS_INIT_PROC | SIO_IO, 0x194 bytes | SIO6509_$INIT (after SIO2681_$INIT) | `[section(os_init_proc, os_init_data)]` |
| PROCEDURE$   | SIO_IO, 0xE0 bytes | SIO6509_$SET_LINE, SIO6509_$INQ_LINE (after SIO2681_$INQ_LINE) | `[section(procedure$, data$)]` |
| WIRED_DATA   | SIO_INT, 0x8C bytes (hand-written) | SIO6509_$PTRS, SIO6509_$INT1_RTE | (no Pascal) |

The routines are therefore fragments of SIO_IO's module, whose module
file the 2681 driver's translation wrote: `sio2681/sio2681.pas`
(`module sio_io, wired_proc, wired_data;`, the map segments' name,
batch D1) includes `sio/sio.ins.pas`, `sio6509/sio6509.ins.pas` and the
five fragments in image order, and declares the table SIO6509_$RCV
reads among the module's variables:

| offset | variable | type |
|--------|----------|------|
| +0xA8 | `sio6509_rcv_flags` | array[0..7] of integer32, `[0, 2, 4, 6, 1, 5, 3, 0]` |

(+0xA8 of the map's SIO_IO data segment in WIRED_DATA, 0xC8 bytes).
Each fragment's attribute names its code section's pair, the same as
SIO_IO's heading names for WIRED_PROC (kbd/get_desc.pas's reasoning).
`tools/pascal_check.sh` checks them with `sio2681/sio2681.pas`.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| SIO6509_$RCV | `rcv.pas` |
| SIO6509_$XMIT | `xmit.pas` (empty procedure) |
| SIO6509_$INIT | `init.pas` |
| SIO6509_$SET_LINE | `set_line.pas` |
| SIO6509_$INQ_LINE | `inq_line.pas` |
| SIO6509_$INT1_RTE | none: hand assembly, `m68k/int1_rte.s` (in the data segment SIO_INT; SIO6509_$PTRS with it) |

All five compiled routines are global (map symbols) and none is nested;
no module-local routine belongs to SIO6509.  Headings
(`sio6509.ins.pas`):
- SIO6509_$RCV `(in chan: sio6509_$chan_t)`, the default convention;
- SIO6509_$XMIT `(in chan; ch: char)`, `val_param`, the shape of
  SIO2681_$XMIT in the same vtable slot (its own code is an empty
  procedure);
- SIO6509_$INIT `(in vec, in chip: integer; var chan; in callback:
  univ_ptr; in config: sio6509_$config_t)`, the default convention (the
  caller passes the constants by address);
- SIO6509_$SET_LINE and _$INQ_LINE `(in chan; in / in out params:
  sio_$params_t; mask: integer32; out status)`, `val_param` (the mask
  read by value).

`sio6509.ins.pas` also declares the channel record, the 32-byte register
block, the configuration bytes, SIO6509_$PTRS and SIO6509_$INT1_RTE
(extern, hand-written), and two objects of the map that no insert file
declared: KEYBD_VEC (0x68, the trap page) and SIO (the register page),
both indexed from 1 with the map symbol as the base.

Changes to shared insert files:
- `sio/sio.ins.pas`: status_$sio_invalid_option, the parameter block
  sio_$params_t, and SIO_$I_RCV's heading (`val_param`: descriptor
  pointer, character, error flags by value).  Since SIO2681 (batch D1)
  the block's flags1 and flags2 are sio_$flags_t, a set of 0..31, and
  `inq_line.pas` reads `flags1 + [1, 2]` (the same code).

No conformance unit of `../domain-pascal/tests/conformance/` covers these
routines (`sio_init_dtte.pas` is SIO's module-local sio_init_dtte).

## The SAU3

The SIO_IO routines are the SAU2's code at the SAU3's addresses but
SIO6509_$INIT, which without `display_driver` does not install
SIO6509_$INT1_RTE in the keyboard's exception vector (`init.pas`;
nothing in the SAU3 image calls SIO6509_$INIT).

## Open items

### TODO(pascal)

- `rcv.pas`: bit 7 of the status tested on the flags of its byte load.
- `init.pas`: 4 frame bytes that nothing addresses (stand-in `unused_4`).
