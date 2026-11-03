# The FIM subsystem in Domain Pascal

The fault interrupt manager.

Most of FIM is hand-written: the code inside the map's data segments
FIM_UNWIRED (0x4F0 bytes), FIM_WIRED (0x1074 bytes) and the second
FIM_WIRED (0x24 bytes), and FIM_$CRASH in the CRASH_SYSTEM data segment
(`sau2/*.s`).  Only the seven routines of the FIM_ code segment (0x664
bytes) are compiler output.

## Layout

One module, `fim.pas`, `module fim_, wired_proc, wired_data;` (the map
segments' name):

| section | code | routines | attribute |
|---------|------|----------|-----------|
| WIRED_PROC | FIM_, 0x664 bytes (SAU5 0x6E0) | FIM_$BUILD_DF (and its cell), FIM_$ACKNOWLEDGE, FIM_$INSTALL, FIM_$GET_FIM_ADDR, FIM_$INIT_ASID, FIM_$FREE_ASID, FIM_$GET_USER_PC | none (the heading's) |

Data: the FIM_ data segment (0x134 bytes) in WIRED_DATA, the module's
variables in `fim.pas` (zero but the frame size table), with the map
symbols FIM_IN_FIM and FIM_$USER_FIM_ADDR `define`d among them
(FIM_IN_FIM, though it has no `$`, is a global symbol: the map lists no
other kind; review):

| offset | variable | type |
|--------|----------|------|
| +0x000 | `fim_in_fim` (FIM_IN_FIM) | array[0..57] of boolean, defined |
| +0x03A | `unused_3a` | integer, never addressed |
| +0x03C | `fim_$user_fim_addr` (FIM_$USER_FIM_ADDR) | array[0..57] of integer32, defined |
| +0x124 | `fim_frame_size` | array[0..15] of fim_$byte_t, `08 08 0c 00 10 00 00 00 3a 14 20 5c 00 00 00 00` |

The FIM_WIRED tables the compiled routines use (FIM_$QUIT_EC,
FIM_$QUIT_VALUE, FIM_$QUIT_INH, FIM_$DELIV_EC) are map symbols of the
hand-written segment, extern in `fim.ins.pas`.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| FIM_$BUILD_DF | `build_df.pas` (and its status cell; with `pbu_driver` the PBU fault path, a second cell, and the FIM_WIRED and PBU_ASM names in `fim.ins.pas`, TODO(merge) for the PBU_ASM routines) |
| FIM_$ACKNOWLEDGE | `acknowledge.pas` |
| FIM_$INSTALL | `install.pas` |
| FIM_$GET_FIM_ADDR | `get_fim_addr.pas` |
| FIM_$INIT_ASID | `init_asid.pas` |
| FIM_$FREE_ASID | `free_asid.pas` |
| FIM_$GET_USER_PC | `get_user_pc.pas` |
| (data) | the module's variables in `fim.pas`; the FIM_WIRED data and FIM_$INITIAL_STACK_SIZE belong to the hand-written segments |

The hand-written routines (in address order; the map's names):

| routine | file |
|---------|------|
| FIM_$CRASH | `m68k/crash.s` |
| FIM_$COM | `m68k/com.s` |
| FIM_$ADDR_ERR, FIM_$ILL_INSTR, FIM_$ZERO_DIV, FIM_$CHK_INSTR, FIM_$TRAPV_INSTR, FIM_$UNDEF_TRAP, FIM_$INV_STACK | `m68k/fault_stubs.s` |
| FIM_$SOFT_FAULT | `m68k/soft_fault.s` |
| FIM_$UII | `m68k/uii.s` |
| FIM_$COPROC | `m68k/coproc.s` |
| FIM_$GENERATE | `m68k/generate.s` |
| FIM_$FP_BSUN, FIM_$FP_INEXACT, FIM_$FP_DIV_ZERO, FIM_$FP_UNDFLO, FIM_$FP_OP_ERR, FIM_$FP_OVRFLO, FIM_$FP_SIG_NAN | `m68k/fp_exceptions.s` |
| FIM_$PRIV_VIOL | `m68k/priv_viol.s` |
| FIM_$ILLEGAL_USP | `m68k/illegal_usp.s` |
| FIM_$TRACE | `m68k/trace.s` |
| FIM_$CLEANUP | `m68k/cleanup.s` |
| FIM_$RLS_CLEANUP | `m68k/rls_cleanup.s` |
| FIM_$POP_SIGNAL | `m68k/pop_signal.s` |
| FIM_$SIGNAL_FIRST, FIM_$SIGNAL | `m68k/signal.s` |
| FIM_$PROC2_STARTUP | `m68k/proc2_startup.s` |
| FIM_$SINGLE_STEP | `m68k/single_step.s` |
| FIM_$FAULT_RETURN | `m68k/fault_return.s` |
| FIM_$INITIAL_STACK_SIZE | `m68k/initial_stack_size.s` (a cell) |
| FIM_$TRACE_BIT | `m68k/trace_bit.s` (a cell at the segment start) |
| (the FIM_WIRED tables) | `m68k/wired_data.s` |
| FIM_$BUS_ERR | `m68k/bus_err.s` |
| FIM_$FLINE | `m68k/fline.s` |
| FIM_$FP_ABORT | `m68k/fp_abort.s` |
| FIM_$FP_INIT | `m68k/fp_init.s` |
| FIM_$FSAVE | `m68k/fsave.s` |
| FIM_$FRESTORE | `m68k/frestore.s` |
| FIM_$FP_GET_STATE | `m68k/fp_get_state.s` |
| FIM_$FP_PUT_STATE | `m68k/fp_put_state.s` |
| FIM_$SPURIOUS_INT, FIM_$SPUR_CNT | `m68k/spurious_int.s` (the second a cell) |
| FIM_$PARITY_TRAP | `m68k/parity_trap.s` |
| FIM_$GET_USER_SR_PTR | `m68k/get_user_sr_ptr.s` |
| FIM_$DELIVER_TRACE_FAULT | `m68k/deliver_trace_fault.s` |
| FIM_$CLEAR_TRACE_FAULT | `m68k/clear_trace_fault.s` |
| FIM_$EXIT | `m68k/exit.s` |
| FIM_$COLD_BUS_ERR | `m68k/cold_bus_err.s` |
| FIM_$SETUP_RETURN (no map symbol) | `m68k/fault_return.s` |
| FIM_$CLEANUP_STACK (no map symbol) | `m68k/signal.s` (a cell) |

All seven compiled routines are global (map symbols); none is nested
and there is no module-local routine.

`fim.ins.pas` holds the fault statuses, FIM_$QUIT_EC, FIM_$QUIT_VALUE,
the delivery-frame constants and statuses, the frame types (the
exception frame with its format variants, the SR/PC, the fault
information, the register area, the delivery frame and its flags byte,
the result), FIM_$QUIT_INH, FIM_$DELIV_EC, FIM_$USER_FIM_ADDR,
BUS_ERROR_VEC, the headings of the hand-written routines the compiled
ones call (FIM_$SIGNAL_FIRST, FIM_$CRASH, FIM_$FP_ABORT, FIM_$FSAVE,
FIM_$GET_USER_SR_PTR, FIM_$CLEAR_TRACE_FAULT, FIM_$COLD_BUS_ERR) and
the seven headings (FIM_$BUILD_DF `val_param`, called by FIM_$COM; the
others the default convention), and what other subsystems use of FIM
(the cleanup handlers, the signals, the FP state, the exception
entries).  OS_STACK_BASE is declared in `proc1/proc1.ins.pas`.

Changes to shared insert files:
- `proc1/proc1.ins.pas`: PROC1_$CURRENT_PCB, PROC1_$GET_LOCKS,
  PROC1_$INHIBIT_CHECK, PROC1_$GET_USP.
- `proc2/proc2.ins.pas`: PROC2_$DELETE, PROC2_$DELIVER_FIM (`univ`
  register and SR/PC parameters, their formal types).
- `as/as.ins.pas`: AS_$GLOBAL_A, AS_$PRIVATE, AS_$STACK_LOW.
- `name/name.ins.pas`: NAME_$CLEANUP.
- `acl/acl.ins.pas`: ACL_$CLEAR_SUPER.
- `peb/peb.ins.pas`: PEB_$GET_STATUS (an integer32 result, the
  status's longword).

Conformance: `../domain-pascal/tests/conformance/fim_get_fim_addr.pas`
is FIM_$GET_FIM_ADDR, byte-identical there.  The tree's body is the
unit's; the unit's block declares a 0x3C-byte pad and char elements
where `fim.pas` has fim_in_fim (booleans), unused_3a and fim_$byte_t
elements: the same offsets and bytes, no code difference.

On the SAU4 FIM_$BUILD_DF takes an access fault's address from the
frame's longword at +0x0A (`fault_frame_addr`) and saves no FPU state
(`fp_state_in_cpu`); its entry also saves FP2..FP7 with a descriptor
for them, which no source construct here produces (its TODO(pascal)).

## Open items

### Behavior

FIM_$BUILD_DF does not clear the fault information first: the fields a
frame format does not set keep the frame's bytes; only the access
faults (whose frames fill it) read it.

### TODO(pascal)

- `build_df.pas`: the frame is not reproduced (the result variable
  between the locals, the register-held locals' slots); bit 23 of a
  status read as the sign of its second byte; the SAU4's FP register
  save around the routine (`fp_state_in_cpu`).
- `init_asid.pas`: 16 frame bytes (stand-in `unused_10`).
- `free_asid.pas`: 4 frame bytes (stand-in `unused_4`).

## Named dispatch codes

fim/fim.ins.pas's dispatch-code block names the exception frame format
codes (`fim_$frame_format_*`; 8 is the 68010 bus fault frame), used in
FIM_$BUILD_DF's `case format of`.
