# The PROC1 subsystem in Domain Pascal

The level-1 process manager (the PCBs, binding and unbinding,
suspension, the timeslice and virtual timers, the load averages, the
process stacks, the process types).

## Layout

One module, `proc1.pas`, `module proc1_, wired_proc, wired_data;` (the
map segments' name; the heading of the byte-identical conformance unit
`../domain-pascal/tests/conformance/proc1_get_loadav.pas`).  It holds
EC_$INIT and EC_$READ of `../ec/` too: they lie inside PROC1_'s code
segment (`../ec/README.md`).

| section | code | routines (image order) | attribute |
|---------|------|------------------------|-----------|
| WIRED_PROC | PROC1_, 0xD88 bytes | PROC1_$TRY_TO_SUSPEND, _$RESUME, _$SUSPEND, _$SUSPENDP, _$TST_LOCK, _$GET_LOCKS, _$SET_ASID, _$VT_INT, _$SET_VT, _$SET_TS, _$TS_END_CALLBACK, proc1_$init_ts_timer, PROC1_$GET_LOADAV, _$LOADAV_CALLBACK, _$INIT_LOADAV, _$BIND, _$UNBIND, _$GET_INFO, _$ALLOC_STACK, _$FREE_STACK, _$CREATE_P, EC_$INIT, EC_$READ, proc1_$clamp_priority, PROC1_$SET_PRIORITY, _$SET_TYPE, _$GET_TYPE, _$GET_LIST, _$GET_ANY_CPUT, _$GET_ANY_CPU_USAGE | none (the heading's) |
| OS_INIT_PROC | PROC1_, 0xD0 bytes | PROC1_$INIT | `[section(os_init_proc, os_init_data)]` |

Data: the PROC1_ data segment (0xCC4 bytes) in WIRED_DATA, through A5 in
the WIRED_PROC routines that use it, by its address in PROC1_$INIT; all
zero in the image:

| offset | variable | type |
|--------|----------|------|
| +0x000 | `proc1_$loadav` | proc1_$loadav_t, 3 longwords |
| +0x00C | `unused_0c`, a stand-in (TODO in proc1.pas) | integer32 |
| +0x010 | `proc1_$loadav_elem` | time_$queue_elem_t (0x1A) |
| +0x02A | `unused_2a`, a stand-in | 3 words |
| +0x030 | `proc1_$ts_elem` | array[1..64] of proc1_$ts_slot_t (0x1C each) |
| +0x730 | `os_stack_base` (OS_STACK_BASE, map symbol, defined) | array[0..64] of linteger |
| +0x834 | `unused_834`, a stand-in | integer32 |
| +0x838 | PROC1_$STATS (`define`d, map symbol) | array[1..64] of proc1_$stats_t (0x10 each) |
| +0xC38 | `proc1_$stack_free_list` | linteger |
| +0xC3C | `proc1_$stack_high_water` | linteger |
| +0xC40 | `proc1_$stack_low_water` | linteger |
| +0xC44 | PROC1_$TYPE (`define`d, map symbol) | array[1..64] of integer |

`ec/init.pas` and `ec/read.pas` carry no section attribute (the module
heading names WIRED_PROC).

Routines: 27 PROC1_ globals (every PROC1_ map symbol of the two code
segments) and EC_'s two; two module-local (`internal`, no map symbol):
proc1_$init_ts_timer and proc1_$clamp_priority.
None is nested.  The hand-written PROC1_ASM routines get no Pascal
(below).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| PROC1_$TRY_TO_SUSPEND | `try_to_suspend.pas` |
| PROC1_$RESUME | `resume.pas` |
| PROC1_$SUSPEND | `suspend.pas` |
| PROC1_$SUSPENDP | `suspendp.pas` |
| PROC1_$TST_LOCK | `tst_lock.pas` |
| PROC1_$GET_LOCKS | `get_locks.pas` |
| PROC1_$SET_ASID | `set_asid.pas` |
| PROC1_$VT_INT | `vt_int.pas` |
| PROC1_$SET_VT | `set_vt.pas` |
| PROC1_$SET_TS | `set_ts.pas` |
| PROC1_$TS_END_CALLBACK | `ts_end_callback.pas` |
| proc1_$init_ts_timer | `init_ts_timer.pas` (internal) |
| PROC1_$GET_LOADAV | `get_loadav.pas` |
| PROC1_$LOADAV_CALLBACK | `loadav_callback.pas` (its `div 256` inline, no routine of its own) |
| PROC1_$INIT_LOADAV | `init_loadav.pas` |
| PROC1_$BIND | `bind.pas` |
| PROC1_$UNBIND | `unbind.pas` |
| PROC1_$GET_INFO | `get_info.pas` |
| PROC1_$ALLOC_STACK | `alloc_stack.pas` |
| PROC1_$FREE_STACK | `free_stack.pas` |
| PROC1_$CREATE_P | `create_p.pas` |
| (EC_$INIT, EC_$READ) | `../ec/init.pas`, `read.pas` |
| proc1_$clamp_priority (internal) | `clamp_priority.pas` |
| PROC1_$SET_PRIORITY | `set_priority.pas` |
| PROC1_$SET_TYPE | `set_type.pas` |
| PROC1_$GET_TYPE | `get_type.pas` |
| PROC1_$GET_LIST | `get_list.pas` |
| PROC1_$GET_ANY_CPUT | `get_any_cput.pas` |
| PROC1_$GET_ANY_CPU_USAGE | `get_any_cpu_usage.pas` |
| PROC1_$INIT | `init.pas` |
| proc1_$ec_waitn | none: hand assembly (PROC1_ASM; `../ec/m68k/wait.s`) |
| PROC1_$REMOVE_READY, proc1_$remove_from_ready_list | none: hand assembly (PROC1_ASM, `m68k/ready_list.s`) |
| PROC1_$REORDER_READY, proc1_$reorder_if_needed | none: hand assembly (PROC1_ASM, `m68k/ready_list.s`) |
| PROC1_$ADD_READY, proc1_$add_ready_body | none: hand assembly (PROC1_ASM, `m68k/ready_list.s`) |
| proc1_$insert_into_ready_list, proc1_$insert_scan | none: hand assembly (PROC1_ASM, `m68k/ready_list.s`) |
| PROC1_$GET_CPUT, PROC1_$GET_CPUT8, proc1_$get_current_cpu_time | none: hand assembly (PROC1_ASM; `m68k/get_cput.s`) |
| PROC1_$GET_CPU_USAGE | none: hand assembly (PROC1_ASM; `m68k/get_cput.s`) |
| PROC1_$BEGIN_ATOMIC_OP, PROC1_$END_ATOMIC_OP | none: hand assembly (PROC1_ASM; `m68k/atomic_op.s`) |
| PROC1_$DISPATCH | none: hand assembly (PROC1_ASM, `m68k/dispatch.s`) |
| PROC1_$INHIBIT_END, PROC1_$INHIBIT_CHECK, PROC1_$INHIBIT_BEGIN | none: hand assembly (PROC1_ASM; `../ml/m68k/exclusion.s`) |
| (data) | the variables in `proc1.pas`; the PROC1_ASM cells are externs in `proc1.ins.pas` (`m68k/proc1_data.s`) |

Headings (`proc1.ins.pas`): the routines taking a pid word (RESUME,
SUSPEND, SUSPENDP, TST_LOCK, SET_ASID, SET_VT, SET_TS, BIND, UNBIND,
ALLOC_STACK, FREE_STACK, CREATE_P, SET_PRIORITY, SET_TYPE, GET_TYPE,
GET_ANY_CPUT) `val_param`; TRY_TO_SUSPEND, VT_INT, GET_LOADAV,
GET_INFO, GET_LIST, GET_ANY_CPU_USAGE the default convention.  No caller
copies an A0 result to D0 (no routine here returns a pointer; ALLOC_STACK
returns its address in D0, a linteger).

## Insert files

- `proc1.ins.pas`, in map order:
  - **PROC1_$AS_ID is `proc1_$asid_t = 0..57`**: the
    image has no sign extension and no signed compare of it (16 zero
    extensions, 12 equality compares, two unsigned multiplies), merges
    its low byte unmasked into 6-bit fields (MAC_OS_$OPEN, XNS_IDP), and
    MSG tests it in 64-member sets with no guard: an
    unsigned subrange within 0..63; the bound 57 is the arrays' it
    indexes (58 address spaces: TIME_'s databases, FIM's, XPD's).  0..63
    fits every site as well, and the check of the whole tree gives the
    same output with `integer', `0..57' and `0..63'.  Its users (some 45
    fragments: audit, fim, ec, mac_os, mac, msg, net_io, pchist, peb,
    pkt, sio, smd, term, time, tty, xns, xpd, and the scratch modules)
    all check.
  - PROC1_$CURRENT_PCB is `proc1_$pcb_ptr_t`, as the byte-identical
    conformance units declare it; FIM's and NETBUF's uses check.
  - proc1_$pcb_t has every field (NETBUF's mypid at +0x44); its +0x40 is
    the conformance unit's variant (a set, a longword).
  - the statuses, the flag members, proc1_$asid_t, the stats, info and
    list types, PROC1_$STATS, PCBS, PROC1_$READY_COUNT, PROC1_$TSVV, and
    the headings of every PROC1_ global and of the PROC1_ASM entries
    called (REMOVE_READY, REORDER_READY, ADD_READY, DISPATCH, INIT_STACK,
    GET_INFO_INT, the locks, the inhibit routines, the CPU time).
  It still needs only base before it.
- `ec/ec.ins.pas`: ADVANCE (`var ec`).
- `time/time.ins.pas`: TIME_$VT_TIMER (`function time_$vt_timer:
  integer`), which PROC1_$SET_VT calls.
- `mmu/mmu.ins.pas`: MMU_$INSTALL_ASID.
- `pmap/pmap.ins.pas`: PMAP_$INIT_WS_SCAN.
- Used as they are: `base`, `cal` (ADD48), `ml`, `misc/crash_system`,
  `wp` (WP_$CALLOC).

## Open items

### Forms the image settles

- The PCB's CPU clock and state word are one 8-byte record (copied and
  filled whole), and its flags one word set (word operations).
- PROC1_$CREATE_P's second argument is read as two words (see the TODO).
- The two bytes before several calls' pushes (SET_TS, TS_END_CALLBACK,
  BIND, GET_INFO, CREATE_P) are the alignment pad.
- proc1_$init_ts_timer has no map symbol (module-local).
- PROC1_$AS_ID is an unsigned subrange (above).

### TODO(pascal)

- `proc1.pas`: the block's three unaddressed gaps (+0x0C, +0x2A,
  +0x834), stand-ins; an 8-byte alignment explains them but
  not PROC1_$TYPE at +0xC44.
- `proc1.pas`: the frames of SET_VT, SET_TS, TS_END_CALLBACK,
  LOADAV_CALLBACK, UNBIND, GET_INFO, ALLOC_STACK and GET_LIST against
  their locals.
- `bind.pas`: the cpu record filled by a byte loop from a cell in the
  code, and the statistics cleared through a stepped pointer.
- `create_p.pas`: the longword argument read as two words; the heading
  is most likely `stack_size: pinteger; proc_type: integer'.  Not
  changed here: its four Pascal callers would change with it.

