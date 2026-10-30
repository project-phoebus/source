# The DXM subsystem in Domain Pascal

The deferred-execution callback queues.

## Layout

One module, `dxm.pas` (map module name `DXM_WIRED_`, so `module
dxm_wired_, wired_proc, wired_data;`), in three code sections and two
data sections:

| section        | code   | routines | attribute |
|----------------|--------|----------|-----------|
| WIRED_PROC     | 0x2F0  | DXM_$ADD_CALLBACK .. DXM_$ADD_SIGNAL | none (the heading's) |
| OS_INIT_PROC   | 0x2C   | DXM_$INIT | `[section(os_init_proc, os_init_data)]` |
| PROCEDURE$     | 0x48   | DXM_$ADD_SIGNAL_CALLBACK | `[section(procedure$, data$)]` |

Data: the map's DXM_WIRED_ segment in WIRED_DATA, 0x63C bytes: the two
rings (module variables, no symbol), then the defined DXM_$OVERRUNS,
DXM_$UNWIRED_Q and DXM_$WIRED_Q (map symbols), the queues with their
masks and ring pointers as initial values.  Its segment in DATA$, 8
bytes: the static table of DXM_$ADD_SIGNAL_CALLBACK, reached through A5,
which is what makes its attribute name DATA$: the rule's "partner data
section" holds, and here the routine's own data force it.  DXM_$INIT
reaches the WIRED_DATA block by its absolute address, as LOG_$INIT and
KBD_$INIT do.  `dxm.pas` gives every object and who addresses it.

`dxm.ins.pas`'s queue `entries` field is a pointer to the ring of
16-byte entries (`dxm_$entries_ptr_t`), and DXM_$ADD_CALLBACK's `data`
is `univ dxm_$data_ptr_t`, since the body dereferences both.  Their
users, `tty/i_signal.pas` and `kbd/rcv.pas`, pass `addr(...)` to the
`univ` formals.

## Routines and their fragments

| routine                     | fragment |
|-----------------------------|----------|
| DXM_$ADD_CALLBACK           | `add_callback.pas` |
| DXM_$SCAN_QUEUE             | `scan_queue.pas` |
| DXM_$HELPER_COMMON | `helper_common.pas` |
| DXM_$HELPER_WIRED | `helper_wired.pas` |
| DXM_$HELPER_UNWIRED | `helper_unwired.pas` |
| DXM_$ADD_SIGNAL             | `add_signal.pas` |
| DXM_$INIT                   | `init.pas` |
| DXM_$ADD_SIGNAL_CALLBACK    | `add_signal_callback.pas` |
| (data)                      | the module's variables and the defined queues in `dxm.pas`; the DATA$ table a static in `add_signal_callback.pas`; DXM_$ADD_SIGNAL's code cell is `addr(dxm_$add_signal_callback)` in `add_signal.pas` |

Every routine is compiled code with a map symbol (global); none is
nested or module-local.  DXM_$HELPER_WIRED and DXM_$HELPER_UNWIRED are
process entry points (OS_$INIT passes their addresses to
PROC1_$CREATE_P) and wrappers: each takes its resource lock and calls
DXM_$HELPER_COMMON with its queue, an ordinary stack argument.
DXM_$ADD_SIGNAL's one caller, the hand-written PEB_$INT, pushes
Pascal word slots that agree with its `val_param` heading.

Insert files: `dxm.ins.pas` (constants, the entry, ring, datum, signal
record and routine pointer types, DXM_$OVERRUNS, DXM_$UNWIRED_Q and
DXM_$WIRED_Q, the eight headings), and what it uses from
`ec/ec.ins.pas` (EC_$WAIT), `proc1/proc1.ins.pas` (PROC1_$SET_LOCK),
`proc2/proc2.ins.pas` (PROC2_$SIGNAL_OS, PROC2_$UID) and
`misc/crash_system.ins.pas` (CRASH_SHOW_STRING).

## Open items

`TODO(pascal)` comments:

- `add_callback.pas`: 16 frame bytes nothing addresses (stand-ins
  unused_20 and unused_30); the byte loop's mismatch branch goes past the
  `if match` test, which `exit` does not give without a threading step
  (a `goto` would, with a dead store).
- `scan_queue.pas`: 4 frame bytes (stand-in unused_14).
- `add_signal.pas`: the record needs an alignment of 8 (as
  `tty/i_wait.pas`).
- `add_signal_callback.pas`: the call through a type-transferred table
  element, `dxm_$signal_routine_t(...)^(...)`, is not a known form, and
  the reference may not allow dereferencing a transfer's result (p.
  4-145, 3.13.2); a table of two-variant records gives the same code
  without it.
- `proc2/proc2.ins.pas`: what PROC2_$SIGNAL_OS's frame longword at -4 is
  (its body is not translated).

Other notes:

- The UID table is a map symbol of its own, PROC2_$UID, inside PROC2's
  data block, which DXM_$ADD_SIGNAL_CALLBACK and the TIME_UNWIRED
  routines address.
- `dxm_$signal_data_t.param` and the signal routines' param are a
  status (PEB_$INT queues 16#00240002, and PROC2_$SIGNAL_PGROUP_OS
  takes a status_$t).
- The signal routine table is a static of DXM_$ADD_SIGNAL_CALLBACK (no
  map symbol; nothing else addresses it).  The WIRED_DATA block is two
  module variables and three defined globals, not one record.
- EC_$WAIT's two three-element arrays by value are six scalar by-value
  parameters in Pascal (the same 24-byte layout; arrays over 4 bytes go
  by address).
- DXM_$HELPER_COMMON's two unused eventcounts are EC_$NIL_EC's address
  (a relocation cell, not nil), pushed twice per call; the pad pushed
  before PROC1_$SET_LOCK in the helpers is the alignment pad.
- Of DXM_$ADD_CALLBACK's callers only KBD_$RCV and TIME_$Q_SCAN_QUEUE
  pop the arguments; TTY_$I_SIGNAL, AST_$SAVE_CLOBBERED_UID, SUMA_$RCV
  and DXM_$ADD_SIGNAL leave them to the epilogue's `unlk`.
- DXM_$SCAN_QUEUE is a `while` whose preheader lock call is merged with
  the body's last one.
