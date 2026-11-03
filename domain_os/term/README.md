# The TERM subsystem in Domain Pascal

The terminal manager (the entry points that map a terminal line to its
real line and pass reads, writes, controls and inquiries to the TTY, SIO
and keyboard drivers, and the records of the lines with their set-up at
boot).

## Layout

Two modules, one per map module name; there is no `term/term.pas`
(`tools/pascal_check.sh` finds both files by their headings).

`os_term.pas`, `module os_term;` (OS_TERM; TTY's shape, tty/tty.pas):

| section | code | routines (image order) | attribute |
|---------|------|------------------------|-----------|
| WIRED_PROC | 0x154 bytes | TERM_$GET_REAL_LINE, KBD_$GET_DESC (kbd/), term_$status_convert (internal), TERM_$SEND_KBD_STRING | `[section(wired_proc, wired_data)]` |
| .TEXT | 0xAA4 bytes | TTY_$I_GET_DESC (tty/), SIO_$I_GET_DESC (sio/), TERM_$READ, TERM_$READ_COND, TERM_$WRITE, TERM_$CONTROL, TERM_$INQUIRE | none (the defaults) |
| PROCEDURE$ | 0x90 bytes | TERM_$GET_EC, TERM_$HELP_CALLBACK | `[section(procedure$, data$)]` |

Data: the OS_TERM WIRED_DATA segment (0x64 bytes), term_$status_convert's
three statics (`status_convert.pas` has the values); the OS_TERM .DATA
segment (4 bytes), TERM_$PCHIST_FLAG, `define`d, zero, which no code
addresses.

`os_term_init.pas`, `module os_term_init, wired_proc, wired_data;`
(OS_TERM_INIT; KBD's and LOG's shape):

| section | code | routines (image order) | attribute |
|---------|------|------------------------|-----------|
| WIRED_PROC | 0x1F0 bytes | KBD_$RESET (kbd/), TERM_$SET_DISCIPLINE, TERM_$SET_REAL_LINE_DISCIPLINE, TERM_$INQ_DISCIPLINE, TONE_$ENABLE (tone/) | `[section(wired_proc, wired_data)]`, the heading's |
| OS_INIT_PROC | 0x7C4 bytes | os_term_init (os/, internal), sio_$init_desc, sio_$init_line, sio_$init_dtte, sio_$init_drain_handler (sio/, internal), SIO_$INIT (sio/), TERM_$INIT | `[section(os_init_proc, os_init_data)]` |
| PROCEDURE$ | 0x74 bytes | TERM_$PCHIST_ENABLE, TERM_$ENQUEUE_TPAD | `[section(procedure$, data$)]` |
| PROC2_DELETE_PRO | 0x60 bytes | TERM_$P2_CLEANUP | `[section(proc2_delete_pro, proc2_delete_dat)]` |

Data: the OS_TERM_INIT WIRED_DATA segment (0x1398 bytes), the module's
variables, laid out with their values in `os_term_init.pas`:

| offset | variable | type |
|--------|----------|------|
| +0x0000 | `term_$serial_params` | sio_$params_t |
| +0x0018 | `term_$tty_handlers` | 10 univ_ptr (TTY_$I_RCV, _OUTPUT_BUFFER_DRAINED, _HUP, _INTERRUPT, _ERR) |
| +0x0040 | `term_$serial_line_handlers` | 6 univ_ptr (SIO_$I_TSTART, _INHIBIT_XMIT, _INHIBIT_RCV, SIO_$I_ERR at 3..6) |
| +0x0058 | `term_$console_params` | sio_$params_t |
| +0x0070 | `term_$console_line_handlers` | 6 univ_ptr (DTTY_$TSTART at 3) |
| +0x0088 | `term_$console_handlers` | 10 univ_ptr (KBD_$RCV, KBD_$OUTPUT_BUFFER_DRAINED) |
| +0x00B0 | `term_$kbd_handlers` | 4 univ_ptr (SIO_$I_TSTART at 2) |
| +0x00C0 | `term_$kbd_rcv` | univ_ptr (TTY_$I_RCV) |
| +0x00C4 | `unused_0c4`, a stand-in | 0x94 bytes |
| +0x0158 | `tty_descs` | array[1..3] of tty_$desc_t |
| +0x0FEC | `unused_fec`, a stand-in | integer32 |
| +0x0FF0 | `sio_descs` | array[1..3] of sio_$desc_t |
| +0x1158 | `term_$console_drain` | array[1..1] of dtty_tstart_t |
| +0x1164 | `unused_1164`, a stand-in | integer32 |
| +0x1168 | `kbd_descs` | array[1..1] of kbd_$desc_t |
| +0x124C | `unused_124c`, a stand-in | integer32 |
| +0x1250 | `term_$console_chan` | sio6509_$chan_t |
| +0x1258 | `term_$sio2681_chip` | sio2681_$chip_t |
| +0x1264 | `unused_1264`, a stand-in | integer32 |
| +0x1268 | `tone_$channel` | sio2681_$channel_t |
| +0x1284 | `term_$serial_chan_b` | sio2681_$channel_t |
| +0x12A0 | DTTE (`define`d, map symbol) | array[0..3] of dtte_t |
| +0x1380 | `unused_1380`, a stand-in | integer32 |
| +0x1384 | TTY_$SPIN_LOCK (`define`d, map symbol) | integer32 |
| +0x1388 | TERM_$MAX_DTTE (`define`d, map symbol) | pinteger |
| +0x138A | `unused_138a`, a stand-in | integer |
| +0x138C | `kbd_$reset_bytes` | 2 integers, 16#FF and 0 (KBD_$RESET's with `kbd_tone`) |
| +0x1390 | `term_$kbd_string` | 6 chars (the block rounded to 0x1398) |

and the OS_TERM_INIT OS_INIT_DATA segment (0x5C bytes), TERM_$INIT's
four statics (`init.pas`).

With `sio16550_lines` (base/config.ins.pas) the WIRED_DATA segment is
0x1A8C bytes and has no OS_INIT_DATA segment.  The first 0xC4 bytes are
the same; then:

| offset | variable | type |
|--------|----------|------|
| +0x00C4 | `unused_0c4`, a stand-in | 0xBC bytes |
| +0x0180 | `tty_descs` | array[1..4] of tty_$desc_t |
| +0x14F0 | `sio_descs` | array[1..4] of sio_$desc_t |
| +0x16D0 | `term_$console_drain` | array[1..1] of dtty_tstart_t |
| +0x16DC | `unused_16dc`, a stand-in | integer32 |
| +0x16E0 | `kbd_descs` | array[1..1] of kbd_$desc_t (0x2A4 bytes, `kbd_key_ring_512`) |
| +0x1984 | `unused_1984`, a stand-in | integer32 |
| +0x1988 | DTTE | array[0..3] of dtte_t |
| +0x1A68 | `unused_1380`, a stand-in | integer32 |
| +0x1A6C | `term_$console_chan_ptr` | sio16550_$chan_ptr_t (SIO_$INIT stores it) |
| +0x1A70 | TTY_$SPIN_LOCK | integer32 |
| +0x1A74 | `unused_1a74`, a stand-in | integer |
| +0x1A76 | TERM_$MAX_DTTE | pinteger |
| +0x1A78 | `kbd_$reset_bytes` | 2 integers |
| +0x1A7C | `term_$kbd_string` | 6 chars |
| +0x1A82 | `tone_$off_string` | 3 chars, 16#FF 16#21 16#82 (`kbd_tone`) |
| +0x1A86 | `tone_$on_string` | 3 chars, 16#FF 16#21 16#81 (`kbd_tone`) |

There the serial driver (SIO16550_$INIT, sio16550/) calls SIO_$INIT for
each of its four ports; TERM_$INIT only calls SUMA_$INIT.

The two module files include the other subsystems' fragments of these
segments (tty/i_get_desc.pas, kbd/get_desc.pas, kbd/reset.pas,
tone/enable.pas, sio/i_get_desc.pas, os/term_init.pas, sio/init_*.pas,
sio/init.pas); the module-local ones have `forward` headings in
`os_term_init.pas` (with `body:` lines).

Routines of TERM: fourteen globals (every TERM_ map symbol) and one
module-local, term_$status_convert (no map symbol), `internal`, which
loads its own A5 because the .TEXT routines call it.  None is nested;
none is hand assembly (TERM_$HELP_CALLBACK is a compiled empty
procedure).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| TERM_$GET_REAL_LINE | `get_real_line.pas` |
| (KBD_$GET_DESC) | `../kbd/get_desc.pas` |
| term_$status_convert | `status_convert.pas` |
| TERM_$SEND_KBD_STRING | `send_kbd_string.pas` |
| (KBD_$RESET) | `../kbd/reset.pas` |
| TERM_$SET_DISCIPLINE | `set_discipline.pas` |
| TERM_$SET_REAL_LINE_DISCIPLINE | `set_real_line_discipline.pas` |
| TERM_$INQ_DISCIPLINE | `inq_discipline.pas` |
| (TONE_$ENABLE) | `../tone/enable.pas` |
| (os_term_init .. SIO_$INIT) | `../os/term_init.pas`, `../sio/init_*.pas`, `../sio/init.pas` |
| TERM_$INIT | `init.pas` |
| (TTY_$I_GET_DESC) | `../tty/i_get_desc.pas` |
| (SIO_$I_GET_DESC) | `../sio/i_get_desc.pas` |
| TERM_$READ | `read.pas` |
| TERM_$READ_COND | `read_cond.pas` |
| TERM_$WRITE | `write.pas` |
| TERM_$CONTROL | `control.pas` |
| TERM_$INQUIRE | `inquire.pas` |
| TERM_$GET_EC | `get_ec.pas` |
| TERM_$HELP_CALLBACK | `help_callback.pas` (empty procedure) |
| TERM_$PCHIST_ENABLE | `pchist_enable.pas` |
| TERM_$ENQUEUE_TPAD | `enqueue_tpad.pas` |
| TERM_$P2_CLEANUP | `p2_cleanup.pas` |
| (data) | `status_convert.pas`, `os_term.pas`, `os_term_init.pas`, `init.pas` |

Headings (`term.ins.pas`, in map order): every TERM_ routine has the
default convention (all arguments by address) but TERM_$GET_REAL_LINE,
`val_param` (the line by value, the callers' word push); its result,
like TERM_$READ's and _$READ_COND's, a pinteger in D0.  No routine
returns a pointer, so no D0 parking.

## Insert files

- `term.ins.pas` (term's own, in map order): the status 16#000B0004;
  `dtte_t`, its first 0x24 bytes three 12-byte eventcounts (ec_00,
  input_ec, output_ec: sio_$init_dtte passes +0x00, +0x0C, +0x18 to
  EC_$INIT, TERM_$GET_EC to EC2_$REGISTER_EC1) and flags a boolean;
  `dtte_ptr_t`; `term_$bits_t` and `term_$value_t`, the value of
  TERM_$CONTROL and _$INQUIRE (a variant record); DTTE, TTY_$SPIN_LOCK,
  TERM_$MAX_DTTE and TERM_$PCHIST_FLAG; the headings of every TERM_
  routine.  It needs only base and suma before it (its users vfmt, kbd,
  suma, pchist and misc's scratch module do not include ec or tty): the
  eventcounts are declared by their bytes, TERM_$GET_EC's handle as a
  univ_ptr.
- `sio/sio.ins.pas`: sio_$params_t's baud_rate is `sio_$rates_t`, two
  words (TERM_$CONTROL stores them one at a time, TERM_$INQUIRE reads
  the second), and its break_mask a `sio_$flags_t` (built and tested as
  a set); `sio_$desc_t` (0x78, its time queue element and eventcount by
  their bytes so that the file needs no other insert) and
  `sio_$desc_ptr_t`, the headings of SIO_$I_INHIBIT_RCV, _INHIBIT_XMIT,
  SIO_$I_ERR (their addresses are OS_TERM_INIT's handler cells),
  SIO_$K_TIMED_BREAK, _SET_PARAM and _INQ_PARAM.
- `tty/tty.ins.pas`: `tty_$uword_t = pinteger`: TERM_$WRITE passes its
  pinteger count's copy to TTY_$K_PUT's `in out` count, TERM_$READ and
  _$READ_COND their count's slot to TTY_$K_GET's `in` count, which ref
  5.3.3 allows only for one type.
- `tpad/tpad.ins.pas` and `tpad/data.pas`: TPAD_$DATA's sample is
  `univ`: its one caller, TERM_$ENQUEUE_TPAD, passes a suma_sample_t, the
  tablet buffer's element; `univ` changes no code under the default
  convention.
- Used as they are: base, ml, ec, dxm, time, cal, proc1, fim, mmu,
  misc/crash_system, proc2, smd, suma, kbd, dtty, sio2681, sio6509,
  tone.

## The SAU3

The DSP has no display console (`display_driver` off,
base/config.ins.pas): its OS_TERM and OS_TERM_INIT are the SAU2's source
with these arms.

- `get_real_line.pas`: real line 0 (the display's) is refused as not
  implemented.
- `../tty/i_get_desc.pas`: no SMD_$UNBLANK.
- `os_term_init.pas`: no console handler blocks, keyboard descriptor
  or console drain record; the block is 0x1228 bytes (tty_descs at
  +0xE0, DTTE at +0x1130); no os_term_init or sio_$init_drain_handler.
- `../sio/init.pas`: port 1 is set up as a serial line with discipline
  2.
- `init.pas`: no console line and no SIO6509_$INIT; the serial lines
  are DTTE 1 and 2 with the first two descriptors (`first_serial`).
  The statics are unchanged.
- `set_real_line_discipline.pas`: discipline 2 stores
  status_$term_invalid_option instead of giving the line to the
  keyboard.
- `enqueue_tpad.pas`: empty.

TERM_$CONTROL, TERM_$INQUIRE and the other routines are the SAU2's
code at the SAU3's addresses and offsets.

## Open items

### Forms the image settles

- `dtte_t`'s first 0x24 bytes are three eventcounts.
- The word at +0x1294 of OS_TERM_INIT's block is the flags field (+0x10)
  of the SIO2681 channel record at +0x1284, the one TERM_$INIT passes to
  SIO2681_$INIT as channel B.
- The function numbers' cells are named by tty/tty.ins.pas's
  enumerators: 13 is tty_$func_stop, 14 tty_$func_start, 8
  tty_$func_quit, 9 tty_$func_int, 10 tty_$func_susp.
- TERM_$INIT's store for mode 1 is the baud rates of the caller's
  line's SIO descriptor (sio_descs[line + 1].params.baud_rate := -1).
- TERM_$SET_REAL_LINE_DISCIPLINE's line is unsigned and its discipline
  the DTTE's word; term_$status_convert is module-local (no map symbol).
- base/base.ins.pas's comment on a status such as 16#00350005 ("reads as
  subsys 0x35") does not match its own layout (modc at byte 1), by which
  it reads as subsys 0, modc 16#35, which is what term_$status_convert
  tests.  Not changed here (another subsystem's comment).

### TODO(pascal)

- `control.pas`: 20 frame bytes no object accounts for (stand-ins).
- `inquire.pas`: 18 frame bytes no object accounts for (stand-ins).
- `init.pas`: 16 frame bytes no object accounts for (a stand-in).
- `os_term_init.pas`: the block's bytes no instruction reaches (0x94 at
  +0xC4 and five longwords; with `sio16550_lines` 0xBC, three longwords
  and a word; without `display_driver` 0x88 at +0x58 and three
  longwords).
- `pchist_enable.pas`: 8 frame bytes of the `sio16550_lines` form no
  object accounts for (a stand-in).
- `../kbd/reset.pas`: 4 frame bytes of the `sio16550_lines` form no
  object accounts for (a stand-in).

## Named dispatch codes

TERM's dispatch codes are named constants: term/term.ins.pas's
dispatch-code block gives TERM_$CONTROL's and TERM_$INQUIRE's option
numbers (term_$opt_*, Apollo's sio.ins.pas sio_$opt_t names where TERM's
number and meaning agree with it, descriptive names where they do
not), TERM_$GET_EC's key (term_$ec_input, _output) and the DTTE's
discipline (term_$disc_*).  control.pas, inquire.pas, get_ec.pas and
set_real_line_discipline.pas use them; tty/i_get_desc.pas,
kbd/get_desc.pas and smd/assoc.pas use the discipline names.  A token
comparison against the previous text (comments stripped, the constants
put back) shows the code unchanged, and a dpc probe gives the same code
for a named constant as for its literal in a case label, a compare, an
`in' argument and a store.
