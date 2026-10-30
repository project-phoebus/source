# The SIO subsystem in Domain Pascal

The serial lines' generic layer (the SIO descriptor of a line: its
receive, transmit-start and modem-signal entries for the drivers, the
TTY's flow-control and error handlers, the kernel calls that set,
inquire and wait on a line, and the initializers that build a line).

## Layout

One module file, `sio.pas`, `module sio;` (the map segments' name; TTY's
shape, no sections named).  SIO's other routines lie in OS_TERM's and
OS_TERM_INIT's segments and are fragments of `../term/os_term.pas` and
`../term/os_term_init.pas`, which include them (the gate checks them
inside those modules).  SIO_IO and SIO_INT are the drivers' modules
(`../sio2681/sio2681.pas`).

| section | code segment | routines (image order) | attribute |
|---------|--------------|------------------------|-----------|
| WIRED_PROC | SIO, 0x3DC | SIO_$I_RCV, SIO_DELAY_RESTART, SIO_$I_XMIT_DONE, SIO_$I_CTS_CHANGE, SIO_$I_DCD_CHANGE, SIO_$I_TSTART, SIO_$I_INHIBIT_RCV, SIO_$I_INHIBIT_XMIT | `[section(wired_proc, wired_data)]` |
| .TEXT | SIO, 0x5E4 | SIO_$I_ERR, SIO_$I_INIT, sio_$set_break, SIO_$K_TIMED_BREAK, SIO_$K_SIGNAL_WAIT, SIO_$K_SET_PARAM, SIO_$K_INQ_PARAM | none |
| OS_INIT_PROC | in OS_TERM_INIT's | sio_$init_desc, sio_$init_line, sio_$init_dtte, sio_$init_drain_handler, SIO_$INIT | `[section(os_init_proc, os_init_data)]` |
| .TEXT | in OS_TERM's | SIO_$I_GET_DESC | none |

Data (all zero in the image):

| block | offset | variable | type |
|-------|--------|----------|------|
| SIO, WIRED_DATA, 8 bytes | +0x0 | SIO_$I_TSTART's static `zero_interval` | time_$clock_t (6 bytes), then 2 bytes of rounding |
| SIO, .DATA, 4 bytes | +0x0 | `sio_$spin_lock` (module variable; no map symbol) | integer32 |

A5: WIRED_DATA's block in SIO_$I_TSTART; .DATA's in SIO_$I_ERR and
SIO_$K_TIMED_BREAK, which sio_$set_break inherits; none elsewhere.

Routines: 14 globals in `sio.pas` (every map symbol of the two SIO
segments; SIO_DELAY_RESTART has no `$`) and SIO_$I_GET_DESC and
SIO_$INIT in the term modules; five module-local (`internal`, no map
symbol): sio_$set_break, sio_$init_desc, sio_$init_line, sio_$init_dtte,
sio_$init_drain_handler.  None is nested, none is hand assembly (`sau2/`
is empty).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| SIO_$I_RCV | `i_rcv.pas` |
| SIO_DELAY_RESTART | `delay_restart.pas` (apart from SIO_$I_TSTART in the image) |
| SIO_$I_XMIT_DONE | `i_xmit_done.pas` |
| SIO_$I_CTS_CHANGE | `i_cts_change.pas` |
| SIO_$I_DCD_CHANGE | `i_dcd_change.pas` |
| SIO_$I_TSTART | `i_tstart.pas` |
| SIO_$I_INHIBIT_RCV | `i_inhibit_rcv.pas` |
| SIO_$I_INHIBIT_XMIT | `i_inhibit_xmit.pas` |
| sio_$init_desc | `init_desc.pas` (in `../term/os_term_init.pas`) |
| sio_$init_line | `init_line.pas` (in `../term/os_term_init.pas`) |
| sio_$init_dtte | `init_dtte.pas` (in `../term/os_term_init.pas`) |
| sio_$init_drain_handler | `init_drain_handler.pas` (in `../term/os_term_init.pas`) |
| SIO_$INIT | `init.pas` (in `../term/os_term_init.pas`) |
| SIO_$I_GET_DESC | `i_get_desc.pas` (in `../term/os_term.pas`) |
| SIO_$I_ERR | `i_err.pas` |
| SIO_$I_INIT | `i_init.pas` |
| sio_$set_break | `set_break.pas` |
| SIO_$K_TIMED_BREAK | `k_timed_break.pas` |
| SIO_$K_SIGNAL_WAIT | `k_signal_wait.pas` |
| SIO_$K_SET_PARAM | `k_set_param.pas` |
| SIO_$K_INQ_PARAM | `k_inq_param.pas` |
| (data) | the variable in `sio.pas`, the static in `i_tstart.pas` |

Headings (`sio.ins.pas`): the SIO_$I_ routines `val_param` (the
descriptor pointer and booleans or a character by value);
SIO_DELAY_RESTART, SIO_$I_INIT and the four SIO_$K_ routines the default
convention (the K_ entries are SVC targets); SIO_$INIT `val_param` with
its two pointer values `in univ` (passed on by address);
SIO_$I_GET_DESC `val_param, a0_return` with an integer32 result: its
four callers, the only ones, all park it in D0, and keep integer32
locals converted at each dereference.  SIO_$I_ERR is a function
(integer32, TTY's status handler type).  The module-local initializers
take their pointer values `in ... univ` (term/os_term_init.pas, the
settled note).

## Insert files

- `sio.ins.pas` (users: `tty/tty.pas`, `term/os_term.pas`,
  `term/os_term_init.pas`, `sio2681/sio2681.pas`): the statuses SIO
  stores, Apollo's subranges sio_$stop_bit_t, sio_$parity_t,
  sio_$word_size_t (SIO_$K_SET_PARAM's range checks are `in_range` of
  these), the state set, the transmit buffer, the handler and driver
  groups and the routine types of the handlers and entries, the driver
  table, the TTY handler group and the line handler block, the
  descriptor (`sio_$desc_t`, needing `ec/ec.ins.pas` and
  `time/time.ins.pas` before it) and the headings.
- Used: `ml`, `ec` (EC_$INIT, EC_$ADVANCE_WITHOUT_DISPATCH, EC_$WAITN),
  `proc1` (PROC1_$AS_ID), `fim` (the quit eventcounts and values), `tty`
  (tty_$desc_t, TTY_$I_INIT, TTY_$I_ENABLE_CRASH_FUNC,
  TTY_$I_OUTPUT_BUFFER_DRAINED), `term` (dtte_t, TERM_$GET_REAL_LINE),
  `dtty` (dtty_tstart_t), `kbd`, `time` (time_$queue_t, TIME_$RTEQ,
  TIME_$WAIT2, TIME_$Q_ADD_CALLBACK), `base`
  (status_$async_fault_while_waiting_for_input).

## Open items

Form and names:
- The .DATA lock has no map symbol (the segment has none inside):
  module-local.
- The descriptor's handlers at +0x28 and driver entries at +0x3C are
  copied as two 16-byte records by sio_$init_desc, so they are groups;
  pending_int and state are sets; the parameter block's char_size,
  stop_bits and parity are Apollo's subranges (0..3, 1..3, 0..3).
- SIO_$INIT has no caller in the image (no cell holds its address).
- sio_$init_line's parameters are the TTY descriptor, the DTTE, the
  line id (the SIO descriptor's or the drain record's address) and the
  line handler block, whose +8 group goes into the TTY descriptor's
  +0x2B4.
- SIO_$I_ERR's result is a status; TTY's handler type reads it as an
  integer32 (the same D0).

### TODO(pascal)

- `delay_restart.pas`: 8 frame bytes no object explains.
- `k_timed_break.pas`: 8 frame bytes (the parking callers' family, the
  TODO in `tty/k_flush_input.pas`).
- `k_signal_wait.pas`: 12 frame bytes.
- `k_set_param.pas`: 8 frame bytes.
- `k_inq_param.pas`: 4 frame bytes.
- `init_line.pas`: the TTY descriptor's four handlers copied as one
  record; tty_$desc_t has them as four fields (grouping them is TTY's
  change).
