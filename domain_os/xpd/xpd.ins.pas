{ xpd/xpd.ins.pas - XPD_$ (the cross-process debug manager), for the
  Domain Pascal tree.

  The statuses, the debugger and target records of XPD_$DATA, the
  debug-state record, the register buffers, and the XPD and XPD_KER
  modules' routine headings, in map order.  Include base/base.ins.pas,
  ec/ec.ins.pas, proc2/proc2.ins.pas, proc2/proc2_data.ins.pas,
  os/os.ins.pas and peb/peb.ins.pas before it.
}

const
  { The XPD statuses the routines store (stcode.db.10.2's texts, module
    16#16 "OS / cross-process debug manager"; stcode.db.10.2 has no text for
    16#00160019). }
  status_$xpd_invalid_state_argument           = 16#00160003;
  status_$xpd_not_a_debugger                   = 16#00160005;
  status_$xpd_debugger_not_found               = 16#00160006;
  status_$xpd_debugger_table_full              = 16#00160007;
  status_$xpd_already_a_debugger               = 16#00160009;
  status_$xpd_target_not_suspended             = 16#0016000B;
  status_$xpd_invalid_ec_key                   = 16#0016000C;
  status_$xpd_state_unavailable_for_this_event = 16#0016000E;
  status_$xpd_invalid_option                   = 16#0016000F;
  status_$xpd_illegal_target_setup             = 16#00160011;
  status_$xpd_target_is_forking                = 16#00160012;
  status_$xpd_target_is_execing                = 16#00160013;
  status_$xpd_target_is_invoking               = 16#00160014;
  status_$xpd_target_is_exiting                = 16#00160015;
  status_$xpd_target_is_loading_exec_image     = 16#00160016;
  status_$xpd_target_is_vforking               = 16#00160017;
  status_$xpd_target_is_signalled              = 16#00160019;

  { The PROC2 statuses XPD stores are declared in proc2/proc2.ins.pas:
    proc2_$uid_not_found (Apollo's customer proc2.ins.pas), and "process
    is not a debug target" and "permission denied" (stcode.db.10.2). }

  { The status XPD_$RESTART reports for a stopped target with no fault
    status: 16#09010000 plus the signal word. }
  xpd_signal_status_base                       = 16#09010000;

  { The members of the PROC2 flags word (proc2/proc2_data.ins.pas
    proc2_$flags_t) XPD uses: a single step is armed, the process is
    stopped for its debugger, its state was handed out, it is a debug
    target. }
  xpd_pf_trace_pending = 1;
  xpd_pf_suspended     = 4;
  xpd_pf_state_saved   = 5;
  xpd_pf_debug_target  = 7;

  { The members of a target's state word tested as a set (xpd_$state_t's
    bits). }
  xpd_state_acked      = 14;
  xpd_state_enabled    = 15;

type
  { The ptrace options: PROC2's entry holds them, so the record is
    proc2/proc2_data.ins.pas's, and this is its XPD name. }
  xpd_$ptrace_opts_t = proc2_$ptrace_opts_t;

  { A target's state word (+0x10 of its record).  Its fields are packed: the
    debugger's slot, three bits, read, cleared and merged on the byte
    (XPD_$SET_DEBUGGER); the event code, four bits across the two bytes, on
    the word (XPD_$SET_DEBUGGER, XPD_$CONTINUE_PROC); the debugger's
    response, two bits, merged on the byte (XPD_$CONTINUE_PROC); `enabled'
    merged from a boolean (XPD_$SET_ENABLE); `acked' set and cleared with
    bit operations (XPD_$GET_EVENT_AND_DATA, XPD_$POST_EVENT).  The tests of
    bits 14 and 15 read the word (XPD_$GET_FP; XPD_$GET_EVENT_AND_DATA),
    which is the form of a constant member of a word set above 7 in memory
    (read as far as the part holding the bit at its number), not of a
    boolean field (a byte test); and XPD_$CLEANUP clears three fields at
    once with one mask on the word, a set difference.  So the word has both
    views. }
  xpd_$state_t = packed record
    case integer of
      1: (enabled: boolean;               { bit 15 }
          acked: boolean;                 { bit 14 }
          response: 0..3;                 { bits 13..12 }
          debugger: 0..7;                 { bits 11..9 }
          event: 0..15;                   { bits 8..5 }
          unused_bits: 0..31);            { bits 4..0 }
      2: (bits: set of 0..15);
  end;

  { A target record of XPD_$DATA, 0x14 bytes: the eventcount the target
    waits on, the event's status, the state word.  pad_12 is never
    addressed. }
  xpd_$target_t = record
    ec: ec_$eventcount_t;                 { 0x00 }
    status: status_$t;                    { 0x0C }
    state: xpd_$state_t;                  { 0x10 }
    pad_12: integer;                      { 0x12 }
  end;

  { A debugger record of XPD_$DATA, 0x10 bytes: the eventcount a target's
    event advances, the debugger's address space (0 = free).  pad_0e is
    never addressed. }
  xpd_$debugger_t = record
    ec: ec_$eventcount_t;                 { 0x00 }
    asid: integer;                        { 0x0C }
    pad_0e: integer;                      { 0x0E }
  end;

  { A fault's SR, PC as the target's stack holds them, 6 bytes, the PC
    at offset 2.  The SR is widened with zeros (XPD_$GET_REGISTERS):
    pinteger; the PC is compared unsigned with the ptrace range
    (XPD_$CAPTURE_FAULT): linteger. }
  xpd_$sr_pc_t = record
    sr: pinteger;                         { 0x00 }
    pc: linteger;                         { 0x02 }
  end;
  xpd_$sr_pc_ptr_t = ^xpd_$sr_pc_t;

  { The register block of the fault (D0..D7, A0..A7; proc2/proc2.ins.pas
    proc2_$fault_regs_t) through a pointer. }
  xpd_$regs_ptr_t = ^proc2_$fault_regs_t;

  { The FP save area, 0x100 bytes (in XPD_$CAPTURE_FAULT's frame): a
    length, then the state, a PEB's register image when there is a PEB
    (XPD_$FP_GET_STATE unloads the PEB into +4 and sets the length to
    32).  The length is compared unsigned (XPD_$GET_REGISTERS, the
    auxiliary area's): linteger. }
  xpd_$fp_buf_t = record
    len: linteger;                        { 0x00 }
    case integer of
      1: (data: array[1..63] of integer32);       { 0x04 }
      2: (peb_state: peb_$fp_state_t);           { 0x04 }
  end;
  xpd_$fp_buf_ptr_t = ^xpd_$fp_buf_t;

  { The auxiliary FP area, 0xF0 bytes (in XPD_$CAPTURE_FAULT's frame): a
    length, then longwords. }
  xpd_$aux_buf_t = record
    len: linteger;                        { 0x00 }
    data: array[1..59] of integer32;      { 0x04 }
  end;
  xpd_$aux_buf_ptr_t = ^xpd_$aux_buf_t;

  { The debug-state record XPD_$CAPTURE_FAULT keeps in its frame and
    publishes in the entry's state_va while the target is stopped; its
    fields are stored at their offsets there; fp_modified a boolean, set
    by XPD_$PUT_REGISTERS and tested by XPD_$CAPTURE_FAULT. }
  xpd_$debug_state_t = record
    frame: xpd_$sr_pc_ptr_t;              { 0x00 }
    regs: xpd_$regs_ptr_t;                { 0x04 }
    fp_buf: xpd_$fp_buf_ptr_t;            { 0x08 }
    aux: xpd_$aux_buf_ptr_t;              { 0x0C }
    fp_modified: boolean;                 { 0x10 }
  end;
  xpd_$debug_state_ptr_t = ^xpd_$debug_state_t;

  { The caller's register buffer of XPD_$GET_REGISTERS and
    _$PUT_REGISTERS, one layout per mode, a univ formal: mode 0 the
    register block (a 64-byte copy); mode 1 as GET_REGISTERS writes it,
    the length, the SR and the PC as longwords, a checksum, the
    auxiliary area's length and its longwords from 0x14, and as
    PUT_REGISTERS reads it, the SR, PC from 6 as one 6-byte record,
    the sum and the length and the longwords up to 212 of them; mode 2
    the FP area's length and longwords, up to 108; mode 3 the fault
    status, the signal, the last PC and the pending mask.  The arrays
    are as long as the largest count the routines accept. }
  xpd_$reg_buf_t = record
    case integer of
      0: (regs: proc2_$fault_regs_t);
      1: (exc_len: linteger;              { 0x00 }
          exc_sr: linteger;               { 0x04 }
          exc_pc: linteger;               { 0x08 }
          exc_sum: integer32;             { 0x0C }
          exc_aux_len: integer32;         { 0x10 }
          exc_words: array[1..212] of integer32);    { 0x14 }
      2: (put_len: linteger;              { 0x00 }
          put_sr_high: integer;           { 0x04 }
          put_sr_pc: xpd_$sr_pc_t;        { 0x06 }
          put_sum: integer32;             { 0x0C }
          put_aux_len: integer32;         { 0x10 }
          put_words: array[1..212] of integer32);    { 0x14 }
      3: (fp_len: linteger;               { 0x00 }
          fp_words: array[1..108] of integer32);     { 0x04 }
      4: (dbg_status: proc2_$fault_param_t;           { 0x00 }
          dbg_signal: integer32;          { 0x04 }
          dbg_pc: linteger;               { 0x08 }
          dbg_pending: set of 0..31);     { 0x0C }
  end;

  { The memory XPD_$READ_PROC and its relatives move: only the address
    of the caller's argument is used, as a number, so a univ formal. }
  xpd_$bytes_t = array[1..1] of char;

  { The memory xpd_$copy_memory moves, reached through an address held
    as a number (os/os.ins.pas os_$data_t, OS_$DATA_COPY's formal). }
  xpd_$data_ptr_t = ^os_$data_t;

  { The one eventcount XPD_$RESTART gives EC_$WAITN (in its frame;
    ec/ec.ins.pas ec_$waitn_ecs_t's element). }
  xpd_$ec_list_t = array[1..1] of ec_$eventcount_ptr_t;

{ ---- Routine headings, map order (XPD's OS_INIT_PROC and .TEXT
  segments, XPD_KER's, XPD's PROC2_DELETE_PRO segment).  All are
  compiled code (link frames, absolute A5 loads);
  all but two are user-callable through the SVC tables (a byte search of
  the image finds each address in a table cell), which call with every
  argument by address, so the default convention; the exceptions are
  named. ---- }

{ XPD_$INIT - wire and clear XPD's tables at boot. }
procedure xpd_$init; extern;

{ XPD_$FIND_INDEX - the process-table index of a target the caller may
  operate on. }
function xpd_$find_index(in proc_uid: uid_$t; out status_ret: status_$t): integer;
  extern;

{ XPD_$SET_PTRACE_OPTS - set a process's ptrace options.
  XPD_$INQ_PTRACE_OPTS - read a process's ptrace options. }
procedure xpd_$set_ptrace_opts(proc_uid: uid_$t; opts: xpd_$ptrace_opts_t;
                               out status_ret: status_$t);
  extern;
procedure xpd_$inq_ptrace_opts(proc_uid: uid_$t; out opts: xpd_$ptrace_opts_t;
                               out status_ret: status_$t);
  extern;

{ XPD_$RESET_PTRACE_OPTS - clear a ptrace option record.
  XPD_$INHERIT_PTRACE_OPTIONS - whether a child inherits the options. }
procedure xpd_$reset_ptrace_opts(out opts: xpd_$ptrace_opts_t); extern;
function xpd_$inherit_ptrace_options(in opts: xpd_$ptrace_opts_t): boolean;
  extern;

{ XPD_$CAPTURE_FAULT - stop the current process for its debugger. }
procedure xpd_$capture_fault(in context: xpd_$regs_ptr_t;
                             in frame: xpd_$sr_pc_ptr_t;
                             in out signal: integer;
                             in out status_ret: proc2_$fault_param_t);
  extern;

{ XPD_$RESTART - resume a stopped target. }
procedure xpd_$restart(proc_uid: uid_$t; in mode: pinteger; in pc: linteger;
                       in signal: integer; in status: status_$t;
                       out status_ret: status_$t);
  extern;

{ XPD_$READ_PROC_ASYNC - read a target's memory without its being
  stopped.
  XPD_$READ_PROC - read a stopped target's memory.
  XPD_$WRITE_PROC - write a stopped target's memory.
  XPD_$READ - read another address space's memory.
  XPD_$WRITE - write another address space's memory. }
procedure xpd_$read_proc_async(proc_uid: uid_$t; in target_mem: univ xpd_$bytes_t;
                               in len: linteger; out buffer: univ xpd_$bytes_t;
                               out status_ret: status_$t);
  extern;
procedure xpd_$read_proc(proc_uid: uid_$t; in target_mem: univ xpd_$bytes_t;
                         in len: linteger; out buffer: univ xpd_$bytes_t;
                         out status_ret: status_$t);
  extern;
procedure xpd_$write_proc(proc_uid: uid_$t; out target_mem: univ xpd_$bytes_t;
                          in len: linteger; in buffer: univ xpd_$bytes_t;
                          out status_ret: status_$t);
  extern;
procedure xpd_$read(in asid: integer; in target_mem: univ xpd_$bytes_t;
                    in len: linteger; out buffer: univ xpd_$bytes_t;
                    out status_ret: status_$t);
  extern;
procedure xpd_$write(in asid: integer; out target_mem: univ xpd_$bytes_t;
                     in len: linteger; in buffer: univ xpd_$bytes_t;
                     out status_ret: status_$t);
  extern;

{ XPD_$SET_DEBUGGER - establish or break a debugger-target link. }
procedure xpd_$set_debugger(debugger_uid: uid_$t; target_uid: uid_$t;
                            out status_ret: status_$t);
  extern;

{ XPD_$GET_EC - the caller's debugger eventcount, registered with EC2. }
procedure xpd_$get_ec(in key: integer; out ec_ret: ec2_$ptr_t;
                      out status_ret: status_$t);
  extern;

{ XPD_$GET_EVENT_AND_DATA - the next event posted to the caller's
  debugger slot. }
procedure xpd_$get_event_and_data(out proc_uid: uid_$t; out event_type: pinteger;
                                  out status_ret: status_$t);
  extern;

{ XPD_$CONTINUE_PROC - let a stopped target go on. }
procedure xpd_$continue_proc(in proc_uid: uid_$t; in response: pinteger;
                             out status_ret: status_$t);
  extern;

{ XPD_$SET_ENABLE - turn event capture for a target on or off. }
procedure xpd_$set_enable(in proc_uid: uid_$t; in enable: boolean;
                          out status_ret: status_$t);
  extern;

{ XPD_$GET_FP - save a stopped target's FP state into its save area.
  XPD_$PUT_FP - restore a stopped target's FP state from its save area. }
procedure xpd_$get_fp(in proc_uid: uid_$t; out status_ret: status_$t); extern;
procedure xpd_$put_fp(in proc_uid: uid_$t; out status_ret: status_$t); extern;

{ XPD_$GET_TARGET_INFO - whether a process is a debug target, and
  whether an event is pending for it. }
procedure xpd_$get_target_info(in proc_uid: uid_$t; out is_target: boolean;
                               out is_suspended: boolean; out status_ret: status_$t);
  extern;

{ XPD_$GET_REGISTERS - read a stopped target's state.
  XPD_$PUT_REGISTERS - change a stopped target's state. }
procedure xpd_$get_registers(proc_uid: uid_$t; in mode: pinteger;
                             out regs: univ xpd_$reg_buf_t;
                             out status_ret: status_$t);
  extern;
procedure xpd_$put_registers(proc_uid: uid_$t; in mode: pinteger;
                             in regs: univ xpd_$reg_buf_t;
                             out status_ret: status_$t);
  extern;

{ XPD_$FP_PUT_STATE - restore a target's FP state from its save areas.
  XPD_$FP_GET_STATE - save a target's FP state into its save areas. }
procedure xpd_$fp_put_state(in fp_buf: xpd_$fp_buf_t; in aux: xpd_$aux_buf_t);
  extern;
procedure xpd_$fp_get_state(out fp_buf: xpd_$fp_buf_t; out aux: xpd_$aux_buf_t);
  extern;

{ XPD_$GET_FP_INT and XPD_$PUT_FP_INT (XPD_KER), called by XPD_$GET_FP
  and _$PUT_FP with a frame word's address and the status's slot: the
  address space read twice through its slot, `in'; the status cleared
  first, `out'.  As ../domain-pascal/tests/conformance/xpd_fp_int.pas. }
procedure xpd_$get_fp_int(in asid: integer; out status_ret: status_$t); extern;
procedure xpd_$put_fp_int(in asid: integer; out status_ret: status_$t); extern;

{ XPD_$CLEANUP - the exit path's XPD teardown for the current process. }
procedure xpd_$cleanup; extern;

{ XPD_$POST_EVENT - a target tells its debugger about an event and
  waits for the response. }
procedure xpd_$post_event(in event_type: pinteger; in status_val: univ status_$t;
                          out response_ret: pinteger);
  extern;

{ XPD_$GET_REGISTERS' and XPD_$PUT_REGISTERS' mode (their `case mode
  of'), and XPD_$RESTART's mode (its jump table) for 1..3; 0, which
  skips the resume and goes straight to the status store, is marked new.
  No Apollo insert declares them. }
const
  xpd_$reg_mode_general = 0;
  xpd_$reg_mode_exception = 1;
  xpd_$reg_mode_fp_state = 2;
  xpd_$reg_mode_debug_state = 3;

  xpd_$restart_mode_no_resume = 0;
  xpd_$restart_mode_continue = 1;
  xpd_$restart_mode_step = 2;
  xpd_$restart_mode_step_no_trace = 3;
