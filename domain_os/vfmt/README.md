# The VFMT subsystem in Domain Pascal

The kernel's formatted text output (the `%`-directive formatter and the
console writer).

## Layout

One module, `vfmt.pas`, `module vfmt;` (the map segment's name):

| section | code | routines | attribute |
|---------|------|----------|-----------|
| .TEXT | 0x970 bytes | vfmt_format_number, VFMT_$MAIN (with four nested routines), VFMT_$WRITE | none (the defaults) |

No data: the map has no VFMT data segment and no routine of the segment
loads A5 or names a data address.  The constant cells are the
compiler's, after VFMT_$MAIN (four chars) and VFMT_$WRITE (three
words); the segment ends with the aligning filler.

The other VFMT_ map segments are hand assembly and get no Pascal: the
thunks VFMT_$FORMATN (0x30 bytes) and VFMT_$WRITEN (0x18 bytes) take
their descriptor in A0 and pop their arguments in forms no compiled code
has, and the 16-byte descriptors VFMT_$FORMATN (VFMT_$FORMAT10,
_ENCODE10, _FORMAT5, _ENCODE5, _ENCODE2, _FORMAT2) and VFMT_$WRITEN
(VFMT_$WRITE10, _WRITE2, _WRITE5) are code in .DATA, a jump to the thunk
with the descriptor's address, and the installed routine's address
(VFMT_$MAIN, VFMT_$WRITE).

Routines, in image order:

| routine | kind |
|---------|------|
| vfmt_format_number | module-local (`internal`): no map symbol, no link, first in the segment |
| vfmt_output_char | nested in VFMT_$MAIN, linked |
| vfmt_get_next_arg | nested in VFMT_$MAIN, passed no link: it lies between nested routines |
| vfmt_parse_number | nested in VFMT_$MAIN, linked |
| vfmt_parse_number_after_m | nested in VFMT_$MAIN, linked |
| VFMT_$MAIN | global |
| VFMT_$WRITE | global |

## Routines and their fragments

| routine | fragment |
|---------|----------|
| vfmt_format_number | `format_number.pas` |
| VFMT_$MAIN | `main.pas` (with vfmt_output_char, vfmt_get_next_arg, vfmt_parse_number, vfmt_parse_number_after_m nested) |
| VFMT_$WRITE | `write.pas` |
| VFMT_$FORMATN | none: hand assembly (the thunk; `m68k/formatn.s`) |
| VFMT_$WRITEN | none: hand assembly (`m68k/writen.s`) |
| VFMT_$WRITE10, VFMT_$WRITE2, VFMT_$WRITE5 | none: hand assembly (the descriptor in .DATA; `m68k/descriptors.s`) |
| VFMT_$FORMAT10, VFMT_$ENCODE10, VFMT_$FORMAT5, VFMT_$ENCODE5, VFMT_$ENCODE2, VFMT_$FORMAT2 | none: hand assembly (the descriptor in .DATA; `m68k/descriptors.s`) |

## Insert files

- `vfmt.ins.pas` (there for DTTY, IO and LOG, which call VFMT_$WRITE2;
  its heading is unchanged): Apollo's `vfmt_$generic_unsigned_arg` and
  `vfmt_$arg_ptr_t` (the argument list), the headings of VFMT_$MAIN and
  VFMT_$WRITE.  The module's own types (the modifier strings, the
  number's value, the output, the string argument's view) are in
  `vfmt.pas`.
- `term/term.ins.pas`: TERM_$WRITE's heading and `term_$chars_t` (the
  buffer type, as TTY_$K_PUT's tty_$chars_t; repeated so that the file
  needs no tty.ins.pas).

## Open items

### Source forms

- vfmt_format_number reads no link and takes everything as parameters:
  it does not reach VFMT_$MAIN's frame.
- spec_len is cleared before each modifier string, not before the main
  loop.
- len_p's frame slot is written only for the call that passes it by
  address; VFMT_$WRITE's count is len itself (its frame has no room for
  a second word).
- The modifier loop has no NUL test: it runs to a terminator, or to the
  "??" exit after ten characters.

### TODO(pascal)

- `main.pas`: VFMT_$MAIN's three pointers into args, kept in step with
  arg_count (strength reduction in a `while` loop, one spilled to the
  frame; the stand-in unused_48).
- `main.pas`: variables whose addresses are passed but which live in
  registers between those uses (width, len, x_count, ch, len_p; and
  VFMT_$WRITE's len): read as one variable each, against dpc's rule (a
  register-held local keeps a slot).
- `main.pas`: the nested routines' `in` character taken by address,
  `univ char` (dpc gives nested routines `internal`'s convention; the
  reference does not say).
