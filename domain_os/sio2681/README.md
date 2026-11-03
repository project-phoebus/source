# The SIO2681 subsystem in Domain Pascal

The 2681 DUART driver (the serial lines).

## Layout

One module, `sio2681.pas`, `module sio_io, wired_proc, wired_data;`:
the map's segment name for both serial drivers' code, so this file is
also the module file of `sio6509/`'s fragments, included in image order
(sio6509/README.md):

| section | segment | routines | attribute |
|---------|---------|----------|-----------|
| WIRED_PROC | SIO_IO, 0x69C bytes | SIO2681_$INT, _$SET_BREAK, _$TONE, sio2681_set_baud_rate, SIO2681_$SET_LINE, _$XMIT; SIO6509_$RCV, _$XMIT | none (the heading's) |
| OS_INIT_PROC | SIO_IO, 0x194 bytes | SIO2681_$INIT; SIO6509_$INIT | `[section(os_init_proc, os_init_data)]` |
| PROCEDURE$ | SIO_IO, 0xE0 bytes | SIO2681_$INQ_LINE; SIO6509_$SET_LINE, _$INQ_LINE | `[section(procedure$, data$)]` |

On the SAU8 (`console_sio2681`, `kbd_tone`) the module has neither
SIO2681_$TONE nor the 6509's routines and table: WIRED_PROC 0x588 bytes,
OS_INIT_PROC 0x154, PROCEDURE$ 0xA8 and WIRED_DATA 0xA8; with
`sio2681_pbu_int` SIO2681_$INIT also acquires the chip's interrupt
through PBU_$ACQUIRE_INT.  The other routines are the SAU2's code.

On the SAU4 (`sio2681_four_lines`) the module has SIO2681_$TONE but not
the 6509's routines and table: WIRED_PROC 0x654 bytes, OS_INIT_PROC
0x130, PROCEDURE$ 0xA8, WIRED_DATA 0xA8; TERM_$INIT calls SIO2681_$INIT
for two chips.  The routines are the SAU2's code.

Data: the map's SIO_IO data segment in WIRED_DATA (0xC8 bytes) is the
module's variables, read through A5 by the WIRED_PROC routines
(`sio2681.pas` lists every object, its value and its readers):

| offset | variable | type |
|--------|----------|------|
| +0x00 | `spin_lock` | integer32 |
| +0x04 | `reserved_04` | integer32 (stand-in) |
| +0x08 | `error_table` | array[0..15] of integer32 |
| +0x48 | `cmd_break_stop`, +0x4A `cmd_break_start` | char |
| +0x4C | `default_baud` | sio2681_$rates_t, 14 and 14 |
| +0x50 | `baud_masks` | array[boolean] of pinteger |
| +0x54..+0x5C | `cmd_reset_mr_ptr`, `cmd_reset_err_enable`, `cmd_reset_rx`, `cmd_reset_tx`, `cmd_disable_rx_tx` | char |
| +0x5E | `mr2_template`, +0x60 `mr1_template` | the MR packed records |
| +0x62 | `baud_bits` | array[0..16] of pinteger |
| +0x84 | `baud_codes` | array[0..16] of 0..15 |
| +0xA6 | `pad_a6` | integer (stand-in) |
| +0xA8 | `sio6509_rcv_flags` | array[0..7] of integer32 (the 6509's) |

The SIO_IO data segment in OS_INIT_DATA (8 bytes) is SIO2681_$INIT's
static `int_vectors`, the two stubs' addresses.  The SIO_INT data
segment (0x8C bytes) is hand assembly (SIO2681_$PTRS, the stubs;
SIO6509_$PTRS and its stub), declared extern.

Routines: every one global (map symbols) but sio2681_set_baud_rate,
module-local (`internal`: no map symbol, no link, before its only caller
SIO2681_$SET_LINE, whose A5 it uses).  None nested.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| SIO2681_$INT | `int.pas` |
| SIO2681_$SET_BREAK | `set_break.pas` |
| SIO2681_$TONE | `tone.pas` |
| sio2681_set_baud_rate | `set_baud_rate.pas` |
| SIO2681_$SET_LINE | `set_line.pas` |
| SIO2681_$XMIT | `xmit.pas` |
| SIO2681_$INIT | `init.pas` |
| SIO2681_$INQ_LINE | `inq_line.pas` |
| SIO2681_$INT1_RTE, SIO2681_$INT2_RTE | none: hand assembly, `m68k/int_rte.s` (in the SIO_INT data segment, with SIO2681_$PTRS) |
| (data) | the WIRED_DATA variables in `sio2681.pas`; the OS_INIT_DATA table a static in `init.pas` |

## Insert files

- `sio2681.ins.pas` (SIO2681_$TONE's heading from TONE's translation,
  kept): the register block (`[device]`, chars), the interrupt-bit,
  input-port, ACR and output-port packed records, the chip and channel
  records, the SIO2681_$PTRS entry, the rate pair, the change mask, the
  configuration; SIO2681_$PTRS and SIO_VEC extern; the stubs; the
  headings of the seven other global routines.
- `sio/sio.ins.pas`: `sio_$flags_t` (a set of 0..31) and the parameter
  block's flags1/flags2 as that set (the bit tests and updates of
  SIO2681_$SET_LINE and _$INQ_LINE), the incompatible-speed status,
  Apollo's parity, character-size and stop-bit codes, and the headings
  of SIO_$I_XMIT_DONE, _CTS_CHANGE, _DCD_CHANGE and _TSTART
  (`val_param`, as SIO_$I_RCV).  Its users: `sio6509/inq_line.pas` uses
  `flags1 + [1, 2]`; `tty/tty.pas` and `term/os_term_init.pas` check.
- `pchist/pchist.ins.pas`: PCHIST_$INTERRUPT's heading.
- `ml/ml.ins.pas`, `sio6509/sio6509.ins.pas` (its `sio`, the SIO page):
  used as they are.

## The SAU3

The SAU3's SIO_IO segments (WIRED_PROC 0x69C, OS_INIT_PROC 0x188,
PROCEDURE$ 0xE0 bytes) and blocks (0xC8 and 8 bytes) are the SAU2's code
and bytes at the SAU3's addresses; the only source difference is
SIO6509_$INIT's (`../sio6509/init.pas`).

## Open items

Form:
- sio2681_set_baud_rate reads no link: a module-local routine that
  inherits its caller's A5, not a nested one.
- The change mask and the parameter block's flags are sets in the image
  (intersections with constant sets, member tests).
- The chip record's config1/config2 are the configuration's first and
  third words.
- baud_codes are words read at their low byte: a 0..15 subrange stored
  in a word and merged into a 4-bit field without a mask.

### TODO(pascal)

- `int.pas`: the loop invariants held in registers (addresses of two
  fields, hoisted; dpc hoists none).
- `set_line.pas`: the even-parity arm's one `andi` for two packed fields.
