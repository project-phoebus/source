# The KBD subsystem in Domain Pascal

The keyboard driver.

## Layout

One module, `kbd.pas` (map module name `KBD`), in three code sections
and one data section:

| section                  | code   | routines | attribute |
|--------------------------|--------|----------|-----------|
| WIRED_PROC               | 0x4F0  | kbd_$state_lookup .. KBD_$PUT | none (the heading's) |
| OS_INIT_PROC             | 0x78   | KBD_$INIT | `[section(os_init_proc, os_init_data)]` |
| PROCEDURE$ (not .TEXT)   | 0xEC   | KBD_$GET_CHAR_AND_MODE .. KBD_$INQ_KBD_TYPE | `[section(procedure$, data$)]` |

With `kbd_commands` (base/config.ins.pas: the SAU6..SAU9) the code is
0x6FC, 0x8C and 0x16C bytes, the WIRED_DATA block 0x108, and a DATA$
block of 0x14 bytes holds KBD_$GET_CHAR_AND_MODE's static command.

The OS_INIT_PROC and PROCEDURE$ attributes name a data section because
those routines reach the WIRED_DATA block as another section's (by its
absolute address), not by A5; `[section(procedure$)]` would keep the
heading's wired_data (`kbd.pas` gives the evidence, with SMD's
PROCEDURE$ module-local routine as the contrast).

Data: the map's KBD data segment, 0xD4 bytes in WIRED_DATA, the
module's own variables (not routine statics: two of them are used by
two routines each, and the block's order is not the routines'), so the
heading is `module kbd, wired_proc, wired_data;`, LOG's shape.  The map
names one interior symbol, `TERM_$TPAD_BUFFER`, a `define`d global of
this module even though its name is TERM_'s: BITPAD's SUMA_$RCV reaches
it by its own address.  `MNK_$KTT_PTRS`/`MNK_$KTT_MAX` and `SMD_$KTT`
are SMD_WIRED's data, externs in `smd/smd.ins.pas`.  `kbd.pas` lists
every object and who addresses it.

## Routines and their fragments

| routine                     | fragment |
|-----------------------------|----------|
| kbd_$state_lookup           | `state_lookup.pas` |
| kbd_$get_mode               | `get_mode.pas` |
| kbd_$txbuf_put              | `txbuf_put.pas` (`kbd_commands` only) |
| kbd_$put_line               | `put_line.pas`: an empty procedure but with `kbd_commands`, between kbd_$get_mode (kbd_$txbuf_put) and kbd_$set_type, far from KBD_$PUT |
| kbd_$set_type               | `set_type.pas` |
| kbd_$send_mode              | `send_mode.pas` (`kbd_commands` only) |
| kbd_$fetch_key              | `fetch_key.pas` |
| kbd_$process_key            | inside `rcv.pas`: nested in KBD_$RCV (it reads the parent's frame through its dynamic link) |
| kbd_$translate_key          | inside `rcv.pas`: nested in KBD_$RCV (it lies in KBD_$RCV's family, between kbd_$process_key and KBD_$RCV, and only KBD_$RCV calls it; it reads no link) |
| KBD_$RCV                    | `rcv.pas` |
| KBD_$CRASH_INIT             | `crash_init.pas` (empty procedure but with `kbd_commands`) |
| KBD_$OUTPUT_BUFFER_DRAINED  | `output_buffer_drained.pas` |
| KBD_$PUT                    | `put.pas` |
| KBD_$INIT                   | `init.pas` |
| KBD_$GET_CHAR_AND_MODE      | `get_char_and_mode.pas` |
| KBD_$SET_KBD_MODE           | `set_kbd_mode.pas` |
| KBD_$SET_KBD_TYPE           | `set_kbd_type.pas` |
| KBD_$INQ_KBD_TYPE           | `inq_kbd_type.pas` |
| KBD_$GET_DESC               | `get_desc.pas`: in the OS_TERM segment, included by `term/os_term.pas`, not by `kbd.pas` |
| KBD_$RESET                  | `reset.pas` (empty procedure but with `kbd_tone`, the keyboard's reset bytes on its 16550 channel with `sio16550_lines`): the first routine of OS_TERM_INIT's WIRED_PROC segment, included by `term/os_term_init.pas`, not by `kbd.pas` |
| (data)                      | the module's variables in `kbd.pas`; MNK_ and SMD_$KTT in `smd/smd.ins.pas` |

Insert files: `kbd.ins.pas` (new), and additions to `base/base.ins.pas`
(status_$invalid_line_number), `smd/smd.ins.pas` (the translation
tables), `suma/suma.ins.pas` (new: the tablet sample and buffer types),
`term/term.ins.pas` (TERM_$MAX_DTTE, TERM_$ENQUEUE_TPAD; it needs
`suma/suma.ins.pas` before it).

Layout facts the descriptor's names do not tell (`kbd.ins.pas`): the
descriptor is 0xE4 bytes (SIO_$INIT steps the console descriptors by
0xE4), and the words at 0x9E/0xA2 are the header of a second
64-character ring, the console's transmit buffer, which SIO_$INIT_DESC
installs as the SIO descriptor's txbuf.  The 2 bytes pushed first before the
calls of kbd_$set_type, kbd_$get_mode, kbd_$translate_key and the
handler is the alignment pad, not a result slot: kbd_$set_type is a
procedure (no caller reads D0), and the handler a procedure type
(KBD_$RCV reads nothing after the call).

## Open items

`TODO(pascal)` comments in the fragments:

- `kbd.pas`: the state table's entries 10..35, which kbd_$state_range
  names and the SAU2's block does not hold (they lie in SIO_IO's
  block; the `kbd_commands` block holds them).
- `state_lookup.pas`: the same out-of-range entries.
- `get_mode.pas`: 4 open frame bytes (stand-in unused_a).
- `set_type.pas`: the signed test after the store, read as a test of the
  field.
- `rcv.pas`: the `while` condition's value in a frame temporary; the
  packed field store on the record's word; no data register used, ch
  read from its slot at each use.
- `put.pas`: 8 open frame bytes (stand-ins unused_8, unused_c).
- `txbuf_put.pas`: 8 open frame bytes (stand-ins unused_8, unused_c).
- `set_kbd_type.pas`: 4 open frame bytes (stand-in unused_8).
- `get_desc.pas`: 4 open frame bytes (stand-in unused_c); the result
  variable's place between the locals.

## Named dispatch codes

KBD_$GET_DESC's discipline 1 is TERM's named constant term_$disc_
disable_alt (term/README.md); the code is unchanged.
