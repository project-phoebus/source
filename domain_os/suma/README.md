# The SUMA (bitpad) subsystem in Domain Pascal

The Summagraphics bitpad tablet driver.

## Layout

One module, `suma.pas`, `module bitpad, wired_proc, wired_data;`: the
map names its three segments BITPAD, and a map segment's name is its
compilation unit's module name (LOG_, KBD, TPAD, TTY, DXM_WIRED_), so
the module is `bitpad` though its routines are SUMA_$ and its directory
suma/.

| section        | code   | routines | attribute |
|----------------|--------|----------|-----------|
| WIRED_PROC     | 0x1B8  | SUMA_$RCV | none (the heading's) |
| OS_INIT_PROC   | 0x28   | SUMA_$INIT | `[section(os_init_proc, os_init_data)]` |

Data: the map's BITPAD data segment, 0x2C bytes in WIRED_DATA, all zero
in the image, no map symbol inside.  Both routines use it (SUMA_$RCV
through A5; SUMA_$INIT by the block's absolute address, another
section's form), so its objects are module variables (LOG's, KBD's and
TPAD's shape) and the heading names wired_proc and wired_data.
SUMA_$INIT has no data of its own and the map no BITPAD block in
OS_INIT_DATA; its attribute names the code section's partner, as
KBD_$INIT's and TPAD_$INIT's do.  The block is six
variables, as TPAD's globals became its scalars: no routine treats it
as one object.  `suma.pas` lists every object, its offset and who
addresses it:

| offset | variable | type |
|--------|----------|------|
| +0x00 | `suma_$last_time` | integer32 |
| +0x04 | `suma_$prev` | suma_sample_t |
| +0x14 | `suma_$cur` | suma_sample_t |
| +0x24 | `suma_$tpad_buffer` | tpad_buffer_ptr_t |
| +0x28 | `suma_$rcv_state` | integer |
| +0x2A | `suma_$threshold` | pinteger |

`suma.ins.pas` (from KBD's translation) also has the thresholds, the
byte type `suma_$byte_t` (`[byte] 0..255`), the packed record of the
identification bits `suma_$id_bits_t`, and the two routine headings.
`suma_sample_t`'s bytes 0x0A..0x0F are a variant part, the first arm
KBD's (chars at 0x0A, 0x0B, which KBD_$RCV stores and takes the
address of) with the coordinates `suma_$byte_t`, the second the packed
record over 0x0A..0x0B that SUMA_$RCV writes and reads with word and
bit operations.  KBD's references (`sample.id_flags`,
`addr(sample.reserved_0b)`, the record copies) are unchanged, and
`kbd/kbd.pas` still checks.  The foreign headings the module needs:
TIME_$CLOCK (`time/time.ins.pas`), DXM_$ADD_CALLBACK and DXM_$UNWIRED_Q
(`dxm/dxm.ins.pas`), TERM_$ENQUEUE_TPAD (`term/term.ins.pas`),
TERM_$TPAD_BUFFER (`kbd/kbd.ins.pas`); SUMA_$RCV's calls agree with
them.

Field roles the names do not tell (`suma.ins.pas`): the byte at 0x0A is
the device type TPAD_$DATA tests (1 = bitpad, set by SUMA_$INIT and never
changed); the identification bits 5..2 of byte 0x0B are what TPAD_$DATA
reads as the bitpad's button state; x_high/y_high (0x0C, 0x0E) are the
coordinates' low six bits and x_low/y_low (0x0D, 0x0F) their high parts,
so the filter's threshold applies to the low parts and the high parts
must match.  tpad_buffer_t's head and tail are compared signed in the
image (integer), which matters only for indices above 32767.

## Routines and their fragments

| routine     | fragment |
|-------------|----------|
| SUMA_$RCV   | `rcv.pas` (no nested or module-local routine; one cell after its code, `addr(term_$enqueue_tpad)` passed to an `in` parameter) |
| SUMA_$INIT  | `init.pas` |
| (data)      | the module's variables in `suma.pas` |

## Open items

### TODO(pascal)

- `rcv.pas`: the sync test is a bit test on the held byte, read as
  `(data_byte & 16#40) <> 0` (that the arms compute in data_byte's
  register in place is noted in the header, not a TODO).
- `rcv.pas`: the threshold's high byte is a byte load of the word, read
  as `rshft(suma_$threshold, 8)` (or `div 256`), compared in 32 bits,
  unsigned.
- `rcv.pas`: the packed fields' constant stores use the record's word,
  the value merge and the reads the byte.
- `rcv.pas`: the 4 frame bytes that nothing addresses (stand-in
  `unused_14`; the `with` lead).
