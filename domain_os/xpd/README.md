# The XPD subsystem in Domain Pascal

The cross-process debug manager (debugger slots, the per-target event
records, capturing a target's faults and process events for its
debugger, resuming it, its memory, registers and FP state).

## Layout

Two module files, one per map module (the checker finds both by their
headings; there is no map module XPD_KER's routines share with XPD):

- `xpd.pas`, `module xpd;`: the map's XPD, in three code sections;
- `xpd_ker.pas`, `module xpd_ker;`: the map's XPD_KER.

| module | section | code | routines (image order) | attribute |
|--------|---------|------|------------------------|-----------|
| XPD | OS_INIT_PROC | 0x90 | XPD_$INIT | `[section(os_init_proc, os_init_data)]` |
| XPD | .TEXT | 0x126C | XPD_$FIND_INDEX, _$SET_PTRACE_OPTS, _$INQ_PTRACE_OPTS, _$RESET_PTRACE_OPTS, _$INHERIT_PTRACE_OPTIONS, xpd_$exec_event (nested), _$CAPTURE_FAULT, _$RESTART, xpd_$copy_memory, _$READ_PROC_ASYNC, _$READ_PROC, _$WRITE_PROC, _$READ, _$WRITE, xpd_$find_debugger_index, xpd_$register_debugger, _$SET_DEBUGGER, _$GET_EC, _$GET_EVENT_AND_DATA, _$CONTINUE_PROC, _$SET_ENABLE, _$GET_FP, _$PUT_FP, _$GET_TARGET_INFO | none (the defaults) |
| XPD | PROC2_DELETE_PRO | 0x1BC | xpd_$unregister_debugger, XPD_$CLEANUP, XPD_$POST_EVENT | `[section(proc2_delete_pro, proc2_delete_dat)]` |
| XPD_KER | .TEXT | 0x420 | XPD_$GET_REGISTERS, _$PUT_REGISTERS, _$FP_PUT_STATE, _$FP_GET_STATE, _$GET_FP_INT, _$PUT_FP_INT | none |

Data:

- XPD's two 4-byte data segments (OS_INIT_DATA, .DATA): zero, no
  object; XPD_$INIT and nine .TEXT routines load A5 with their ends and
  never use it (a TODO in `xpd.pas`).
- XPD_$DATA (0x4E8 bytes), a load section with no module segment, an
  overlay section (`var (xpd_$data)` in `xpd.pas`):

| offset | variable | type |
|--------|----------|------|
| +0x000 | `xpd_$targets` | array[0..57] of xpd_$target_t (0x14 each), by address space |
| +0x488 | `xpd_$debuggers` | array[1..6] of xpd_$debugger_t (0x10 each) |

  The slots are 1..6 at +0x488 and nothing overlaps (58 * 0x14 =
  0x488).  The target records are indexed by address space
  (PROC2_$FIND_ASID's result, PROC1_$AS_ID), the index of PROC2_$UID for
  the same record.
- PROC2's process table (PROC2_$DATA, another overlay section) and the
  per-process eventcounts (PROC2_$EC): `../proc2/proc2_data.ins.pas`,
  for the units that reach them.

Routines: 29 globals (every map symbol of the four code segments: 23 in
XPD's OS_INIT_PROC, .TEXT and PROC2_DELETE_PRO segments, 6 in
XPD_KER); four module-local (`internal`, no map symbol):
xpd_$copy_memory, xpd_$find_debugger_index, xpd_$register_debugger,
xpd_$unregister_debugger; one nested,
xpd_$exec_event in XPD_$CAPTURE_FAULT, which reaches its parent's
variables through its static link.  None is hand assembly; there is no
`xpd/sau2/`.  No routine returns a pointer, so no D0 parking.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| XPD_$INIT | `init.pas` |
| XPD_$FIND_INDEX | `find_index.pas` |
| XPD_$SET_PTRACE_OPTS | `set_ptrace_opts.pas` |
| XPD_$INQ_PTRACE_OPTS | `inq_ptrace_opts.pas` |
| XPD_$RESET_PTRACE_OPTS | `reset_ptrace_opts.pas` |
| XPD_$INHERIT_PTRACE_OPTIONS | `inherit_ptrace_options.pas` |
| xpd_$exec_event, XPD_$CAPTURE_FAULT | `capture_fault.pas` (nested) |
| XPD_$RESTART | `restart.pas` |
| xpd_$copy_memory | `copy_memory.pas` |
| XPD_$READ_PROC_ASYNC | `read_proc_async.pas` |
| XPD_$READ_PROC | `read_proc.pas` |
| XPD_$WRITE_PROC | `write_proc.pas` |
| XPD_$READ | `read.pas` |
| XPD_$WRITE | `write.pas` |
| xpd_$find_debugger_index | `find_debugger_index.pas` |
| xpd_$register_debugger | `register_debugger.pas` |
| XPD_$SET_DEBUGGER | `set_debugger.pas` |
| XPD_$GET_EC | `get_ec.pas` |
| XPD_$GET_EVENT_AND_DATA | `get_event_and_data.pas` |
| XPD_$CONTINUE_PROC | `continue_proc.pas` |
| XPD_$SET_ENABLE | `set_enable.pas` |
| XPD_$GET_FP | `get_fp.pas` |
| XPD_$PUT_FP | `put_fp.pas` |
| XPD_$GET_TARGET_INFO | `get_target_info.pas` |
| XPD_$GET_REGISTERS | `get_registers.pas` (XPD_KER) |
| XPD_$PUT_REGISTERS | `put_registers.pas` (XPD_KER) |
| XPD_$FP_PUT_STATE | `fp_put_state.pas` (XPD_KER) |
| XPD_$FP_GET_STATE | `fp_get_state.pas` (XPD_KER) |
| XPD_$GET_FP_INT | `get_fp_int.pas` (XPD_KER) |
| XPD_$PUT_FP_INT | `put_fp_int.pas` (XPD_KER) |
| xpd_$unregister_debugger | `unregister_debugger.pas` |
| XPD_$CLEANUP | `cleanup.pas` |
| XPD_$POST_EVENT | `post_event.pas` |
| (data) | the overlay in `xpd.pas`; the constant cells are the literals passed by address |

Related routines that are not adjacent in the image have fragments of
their own: XPD_$CAPTURE_FAULT (capture_fault.pas) apart from the other
event routines (get_ec.pas .. set_enable.pas), xpd_$unregister_debugger
(unregister_debugger.pas) apart from the other debugger routines
(find_debugger_index.pas .. set_debugger.pas), and the FP routines of
XPD (get_fp.pas, put_fp.pas) apart from XPD_KER's (get_fp_int.pas,
put_fp_int.pas).

Headings (`xpd.ins.pas`, map order): the default convention throughout
(the SVC tables call with every argument by address; xrefs and a byte
search of the image give the cells); value parameters copied by the
callee where the routine copies them (the UIDs, SET_PTRACE_OPTS'
options); the module-local routines `internal` (words and longwords by
value).  The conformance units
`../domain-pascal/tests/conformance/xpd_reset_ptrace_opts.pas`,
`xpd_inherit_ptrace_options.pas` and `xpd_fp_int.pas` compile three of
them byte for byte.  XPD_$READ has no caller in the image (no xrefs, no
byte of its address).  FIM_$FP_GET_STATE's and _$FP_PUT_STATE's second
argument is the auxiliary area, which those routines treat as a second
buffer; PROC2_$FIND_ASID's second argument chooses the alternate
address space (flag 11, +0x98).

The four FP routines test PEB_$INFO (a 68881, else the PEB board) only
with `peb_board' (base/config.ins.pas: the SAU2 and SAU5); without it
they call FIM_ and FP_ directly, and XPD_$FP_PUT_STATE's and
_$FP_GET_STATE's stand-in local is not declared.  The SAU9's XPD and
XPD_KER are otherwise this source (XPD_$PUT_REGISTERS's SAU4..SAU9 code
differs from the SAU2's in register choice only).

## Insert files

- `xpd.ins.pas` (new): the XPD statuses, the lock number, the flag and
  state members, the target and debugger records, the state word (a
  packed record with a set view), the debug-state record and its areas,
  the register buffer's layouts, the headings of the 29 globals.
- `../proc2/proc2_data.ins.pas` (new): PROC2_LOCK_ID, the ptrace options
  record, the fault status record, the flags set, proc2_info_t (0xE4
  bytes, every field at its offset: checked with dpc's displacements),
  proc2_ec_entry_t, PROC2_$EC, and the overlay PROC2_$DATA with the
  process table and the PID-to-index table.
- Appended, nothing existing changed:
  - `../proc2/proc2.ins.pas`: PROC2_$FIND_INDEX, _$FIND_ASID,
    _$AWAKEN_GUARDIAN, and the PROC2 statuses XPD stores;
  - `../proc1/proc1.ins.pas`: PROC1_$SET_ASID, _$SUSPEND, _$RESUME;
  - `../acl/acl.ins.pas`: ACL_$CHECK_DEBUG_RIGHTS;
  - `../os/os.ins.pas`: OS_$DATA_ZERO;
  - `../fp/fp.ins.pas`: FP_$GET_FP, FP_$PUT_FP;
  - `../fim/fim.ins.pas`: fault_$single_step, fault_$blast (Apollo's
    fault.ins.pas), fim_$trace_sts_t and FIM_$TRACE_STS, fim_$fp_area_t,
    FIM_$FP_GET_STATE, FIM_$FP_PUT_STATE;
  - `../mst/mst.ins.pas`: status_$mst_guard_fault.
- Used as they are: `base`, `ec` (EC_$INIT, _$ADVANCE, _$READ, _$WAIT,
  _$WAITN, EC2_$REGISTER_EC1, ec_$nil_ec), `ml`, `misc/crash_system`,
  `peb` (PEB_$INFO, _$LOAD_REGS, _$UNLOAD_REGS, _$GET_FP, _$PUT_FP).

## Open items

XPD_$CAPTURE_FAULT's handling of a signal the debugger leaves pending:
when the signal is not in the target's sig_blocked_2, the image returns
(delivering it) if its bit is clear in sig_blocked_1, and swallows it
(the ignore path: quit inhibit cleared, signal 0) if the bit is set.
The Pascal follows the image.

### TODO(pascal)

- `xpd.pas`: the two 4-byte data blocks and the A5 loads into them.
- `capture_fault.pas`: 0x1C frame bytes nothing explains.
- `find_debugger_index.pas`: frame bytes of the search loops
  (find_debugger_index, register_debugger, GET_EVENT_AND_DATA,
  unregister_debugger), with the
  lead that the loops are `with' statements under another parameter
  name.
- `get_registers.pas`, `put_registers.pas`, `fp_put_state.pas`,
  `fp_get_state.pas`: the XPD_KER frames.

## Named dispatch codes

XPD's dispatch codes are named constants: xpd/xpd.ins.pas gives the register
modes (xpd_$reg_mode_*) and the restart modes (xpd_$restart_mode_*), used by
the `case's of get_registers.pas, put_registers.pas and restart.pas.
