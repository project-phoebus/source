{ proc1/proc1.ins.pas - PROC1_ (level-1 process) declarations, for the
  Domain Pascal tree.

  The process control block, the statuses, the variables and the
  routine headings of the PROC1_ module (proc1/proc1.pas) and of the
  hand-written PROC1_ASM segment, in the map's order.  The file needs
  only base/base.ins.pas before it.
}

const
  { The statuses of the level-1 process manager, the names of the SR10.2
    status text (stcodes: "OS / level 1 process manager"). }
  status_$illegal_process_id = 16#000A0001;
  status_$process_not_suspended = 16#000A0003;
  status_$process_already_suspended = 16#000A0004;
  status_$process_not_bound = 16#000A0005;
  status_$no_pcb_is_available = 16#000A0008;
  status_$no_stack_space_is_available = 16#000A0009;
  status_$process_not_suspendable = 16#000A000A;

  { The members of a PCB's flag word (proc1_$pcb_t.flags, below), bits
    of the word at +0x54. }
  proc1_flag_waiting = 0;
  proc1_flag_suspended = 1;
  proc1_flag_defer_susp = 2;
  proc1_flag_bound = 3;
  proc1_flag_boosted = 4;

type
  { The address space number, PROC1_$AS_ID's type (below). }
  proc1_$asid_t = 0..57;

  { A process control block, 0x68 bytes:
    - nextp/prevp link the ready list;
    - the saved registers D2..D7, A2..A7 at 0x08..0x37 and the user
      stack pointer at 0x38;
    - resource_locks_held at 0x40, a set of lock numbers, also read
      whole as a longword: a variant;
    - mypid at 0x44, asid at 0x46; vtimer at 0x48, the virtual timer's
      word;
    - cpu at 0x4C: the CPU clock and the state word as one 8-byte
      record;
    - flags at 0x54, a word set (the constants above);
    - inh_count at 0x56 and sw_bsr at 0x58, the lowest and highest
      state;
    - nesting_depth at 0x5A, the inhibited regions' depth;
    - field_5c, field_60, field_64 (PROC1_$GET_ANY_CPU_USAGE returns the
      last two).
    The pointer type is declared first (ref 3.11: a pointer type may
    name a type declared later in the same part). }
  proc1_$pcb_ptr_t = ^proc1_$pcb_t;
  proc1_$flags_t = set of 0..15;
  proc1_$cpu_t = record
    total: time_$clock_t;                 { 0x00 }
    state: integer;                       { 0x06 }
  end;
  proc1_$pcb_t = record
    nextp: proc1_$pcb_ptr_t;              { 0x00 }
    prevp: proc1_$pcb_ptr_t;              { 0x04 }
    save_regs: array[1..12] of integer32; { 0x08: D2..D7, A2..A7 }
    save_usp: univ_ptr;                   { 0x38 }
    wait_start: integer32;                { 0x3C }
    case integer of                       { 0x40 }
      1: (resource_locks_held: set of 0..31;
          mypid: pinteger;                { 0x44 }
          asid: integer;                  { 0x46 }
          vtimer: integer;                { 0x48 }
          pad_4a: integer;                { 0x4A }
          cpu: proc1_$cpu_t;              { 0x4C }
          flags: proc1_$flags_t;          { 0x54 }
          inh_count: integer;             { 0x56 }
          sw_bsr: integer;                { 0x58 }
          nesting_depth: integer;         { 0x5A }
          field_5c: integer32;            { 0x5C }
          field_60: integer32;            { 0x60 }
          field_64: integer32);           { 0x64 }
      2: (resource_locks_word: integer32);
  end;

  { One record of PROC1_$STATS, four longword counters. }
  proc1_$stats_t = record
    stat: array[1..4] of integer32;       { 0x00 }
  end;

  { What PROC1_$GET_INFO returns, 0x18 bytes: the PCB's flag word at 0,
    the user registers PROC1_$GET_INFO_INT stores (usr at 2, upc at 4,
    usp at 8, usb at 0xC), and the PCB's 8-byte cpu record at 0x10. }
  proc1_$info_t = record
    flags: proc1_$flags_t;                { 0x00 }
    usr: integer;                         { 0x02 }
    upc: integer32;                       { 0x04 }
    usp: integer32;                       { 0x08 }
    usb: integer32;                       { 0x0C }
    cpu: proc1_$cpu_t;                    { 0x10 }
  end;

  { An entry of PROC1_$GET_LIST's list, 4 bytes: the pid and the
    process's type, stored as words. }
  proc1_$list_entry_t = record
    pid: pinteger;                        { 0x00 }
    proc_type: integer;                   { 0x02 }
  end;
  proc1_$list_t = array[1..64] of proc1_$list_entry_t;

  { The three load averages, the type of the byte-identical conformance
    unit ../domain-pascal/tests/conformance/proc1_get_loadav.pas. }
  proc1_$loadav_t = array[1..3] of integer32;

var
  { OS_STACK_BASE (map symbol, in PROC1_'s data segment at +0x730;
    defined by proc1/proc1.pas): the OS stack's top per process, indexed
    by pid from 0 (no code reaches element 0). }
  os_stack_base: extern array[0..64] of linteger;

  { OS_STACK and OS_STACK_END (map symbols, the bounds of the map's
    UNWIRED_STACKS data segment, the SAU's linker script) and
    P1_STACK_BASE (map symbol of the STACK data segment, the top of
    process 1's stack): labels as characters, as os/os.ins.pas declares
    the STACK segment's others. }
  os_stack: extern char;
  os_stack_end: extern char;
  p1_stack_base: extern char;

  { PROC1_$STATS (map symbol, in PROC1_'s data segment at +0x838;
    defined by proc1/proc1.pas): four counters per process, indexed by
    pid from 1 at the symbol. }
  proc1_$stats: extern array[1..64] of proc1_$stats_t;

  { PROC1_$TYPE (map symbol, at +0xC44 of PROC1_'s data segment; defined
    by proc1/proc1.pas): a word per process, 64 words, indexed from 1 at
    the symbol. }
  proc1_$type: extern array[1..64] of integer;

{ PROC1_$TRY_TO_SUSPEND - suspend a process now, or mark it for later. }
procedure proc1_$try_to_suspend(var pcb: proc1_$pcb_t); extern;

{ PROC1_$RESUME - resume a suspended process.
  PROC1_$SUSPEND - suspend a process. }
procedure proc1_$resume(pid: pinteger; out status_p: status_$t);
  options(extern, val_param);
function proc1_$suspend(process_id: pinteger; out status_ret: status_$t): boolean;
  options(extern, val_param);

{ PROC1_$SUSPENDP - whether a process is suspended. }
function proc1_$suspendp(pid: pinteger; out status_ret: status_$t): boolean;
  options(extern, val_param);

{ PROC1_$TST_LOCK - whether the current process holds a resource lock.
  PROC1_$GET_LOCKS - the current process's lock set as a longword. }
function proc1_$tst_lock(lock_id: integer): boolean; options(extern, val_param);
function proc1_$get_locks: integer32; extern;

{ PROC1_$SET_ASID - give the current process an address space. }
procedure proc1_$set_asid(asid: integer); options(extern, val_param);

{ PROC1_$VT_INT - fold the virtual timer into the current process's CPU
  time. }
procedure proc1_$vt_int(out vt: time_$clock_t); extern;

{ PROC1_$SET_VT - set a process's virtual timer. }
procedure proc1_$set_vt(pid: pinteger; in delay: time_$clock_t;
                        out status: status_$t);
  options(extern, val_param);

{ PROC1_$SET_TS - re-arm a process's timeslice timer. }
procedure proc1_$set_ts(pcb: proc1_$pcb_ptr_t; timeslice: integer);
  options(extern, val_param);

{ PROC1_$TS_END_CALLBACK - a process's timeslice has run out. }
procedure proc1_$ts_end_callback(in elem: univ_ptr); extern;

{ PROC1_$GET_LOADAV - the three load averages. }
procedure proc1_$get_loadav(out avg: proc1_$loadav_t); extern;

{ PROC1_$LOADAV_CALLBACK - update the load averages. }
procedure proc1_$loadav_callback(in elem: univ_ptr); extern;

{ PROC1_$INIT_LOADAV - start the load-average timer. }
procedure proc1_$init_loadav; extern;

{ PROC1_$BIND - bind a new process to a free PCB. }
function proc1_$bind(entry: univ_ptr; initial_sp: univ_ptr;
                     stack_base: linteger; ws_param: integer;
                     out status_p: status_$t): pinteger;
  options(extern, val_param);

{ PROC1_$UNBIND - unbind a process from its PCB. }
procedure proc1_$unbind(pid: pinteger; out status: status_$t);
  options(extern, val_param);

{ PROC1_$GET_INFO - a process's flags, CPU time and user registers. }
procedure proc1_$get_info(in pidp: integer; out info_ret: proc1_$info_t;
                          out status_ret: status_$t); extern;

{ PROC1_$ALLOC_STACK - allocate and map a process stack.
  PROC1_$FREE_STACK - put a stack on the free list. }
function proc1_$alloc_stack(size: pinteger; out status_ret: status_$t): linteger;
  options(extern, val_param);
procedure proc1_$free_stack(stack: linteger); options(extern, val_param);

{ PROC1_$CREATE_P - create a level-1 process. }
function proc1_$create_p(proc: univ_ptr; proc_type: integer32;
                         out status: status_$t): pinteger;
  options(extern, val_param);

{ PROC1_$SET_PRIORITY - set or read a process's priority range. }
procedure proc1_$set_priority(pid: pinteger; set_it: boolean;
                              var min_priority: integer;
                              var max_priority: integer);
  options(extern, val_param);

{ PROC1_$SET_TYPE - record a process's type. }
procedure proc1_$set_type(pid: pinteger; proc_type: integer);
  options(extern, val_param);

{ PROC1_$GET_TYPE - a process's type.
  PROC1_$GET_LIST - the bound processes with no address space.
  PROC1_$GET_ANY_CPUT - any process's CPU time.
  PROC1_$GET_ANY_CPU_USAGE - any process's CPU time and two counters. }
procedure proc1_$get_type(pid: pinteger; out type_ret: integer);
  options(extern, val_param);
procedure proc1_$get_list(out count_ret: integer; out list_ret: proc1_$list_t);
  extern;
procedure proc1_$get_any_cput(out cpu_time_ret: time_$clock_t; pid: pinteger);
  options(extern, val_param);
procedure proc1_$get_any_cpu_usage(in pid_ptr: pinteger;
                                   out cpu_time_ret: time_$clock_t;
                                   out stat1_ret: integer32;
                                   out stat2_ret: integer32); extern;

{ PROC1_$INIT - initialize the level-1 process manager. }
procedure proc1_$init; extern;

{ The hand-written PROC1_ASM segment (a data segment in WIRED_DATA), its
  variables and the entries compiled code calls, in the map's order. }

var
  { PROC1_$CURRENT_PCB (map symbol, the first cell of the hand-written
    PROC1_ASM): the current process's control block. }
  proc1_$current_pcb: extern proc1_$pcb_ptr_t;

  { PCBS (map symbol): the PCBs' addresses, indexed by pid from 0 at the
    symbol, 65 longwords to PROC1_$READY_COUNT. }
  pcbs: extern array[0..64] of proc1_$pcb_ptr_t;

  { PROC1_$READY_COUNT (map symbol): the number of ready processes. }
  proc1_$ready_count: extern integer;

  { PROC1_$TSVV (map symbol): the timeslice per state, 18 words to
    PROC1_$SUSPEND_EC, indexed by the state from 1 at the symbol. }
  proc1_$tsvv: extern array[1..18] of integer;

  { PROC1_$CURRENT (map symbol, MARKED, the word before PROC1_$AS_ID):
    the current process's number. }
  proc1_$current: extern pinteger;

  { PROC1_$AS_ID (map symbol, in the PROC1 data run): the current address
    space's number, written by the hand-written MMU_$INSTALL_ASID.  An
    unsigned subrange, proc1_$asid_t: every use widens it with zeros,
    compares it for equality or multiplies it unsigned, and fits it in 6
    bits or a 64-member set.  Its bound: 0..57, the 58 address spaces of
    the arrays it indexes (time/time.ins.pas time_$db_t, fim/fim.ins.pas,
    XPD's 58 target records); 0..63 fits every site as well
    (proc1/README.md). }
  proc1_$as_id: extern proc1_$asid_t;

{ PROC1_$REMOVE_READY, PROC1_$REORDER_READY, PROC1_$ADD_READY (hand
  assembly in PROC1_ASM, proc1/m68k/ready_list.s): the PCB by
  address. }
procedure proc1_$remove_ready(var pcb: proc1_$pcb_t); extern;
procedure proc1_$reorder_ready(var pcb: proc1_$pcb_t); extern;
procedure proc1_$add_ready(var pcb: proc1_$pcb_t); extern;

{ PROC1_$GET_CPUT8 (hand assembly in PROC1_ASM, proc1/m68k/get_cput.s):
  the current process's CPU time as a clock. }
procedure proc1_$get_cput8(out cpu_time: time_$clock_t); extern;

{ PROC1_$GET_CPU_USAGE (hand assembly, a map symbol;
  proc1/m68k/get_cput.s): PROC1_$GET_ANY_CPU_USAGE's three results for
  the current process. }
procedure proc1_$get_cpu_usage(out cpu_time_ret: time_$clock_t;
                               out stat1_ret: integer32;
                               out stat2_ret: integer32); extern;

{ PROC1_$DISPATCH (hand assembly in PROC1_ASM, proc1/m68k/dispatch.s). }
procedure proc1_$dispatch; extern;

{ INIT_STACK (map symbol, hand assembly in PROC1_ASM,
  proc1/m68k/init_stack.s): a new process's PCB, entry and stack. }
procedure init_stack(var pcb: proc1_$pcb_t; in entry: univ_ptr;
                     in sp: univ_ptr); extern;

{ PROC1_$SET_LOCK (hand assembly in the PROC1 data run,
  proc1/m68k/set_lock.s): the lock number by value (`val_param'). }
procedure proc1_$set_lock(lock_id: integer); options(extern, val_param);

{ PROC1_$CLR_LOCK (hand assembly in the PROC1 data run,
  proc1/m68k/clr_lock.s), the counterpart of PROC1_$SET_LOCK. }
procedure proc1_$clr_lock(lock_id: integer); options(extern, val_param);

{ PROC1_$INHIBIT_CHECK (hand assembly, ml/m68k/exclusion.s): whether
  the PCB, by value (`val_param'), is inside an inhibited region. }
function proc1_$inhibit_check(pcb: univ_ptr): boolean;
  options(extern, val_param);

{ PROC1_$GET_USP (hand assembly, proc1/m68k/misc.s): the user stack
  pointer. }
function proc1_$get_usp: integer32; extern;

{ PROC1_$GET_INFO_INT (hand assembly in PROC1_ASM, proc1/m68k/misc.s):
  a process's user registers from its OS stack (`val_param'). }
procedure proc1_$get_info_int(pid: integer; stack_base: linteger;
                              stack_top: linteger; out usr_ret: integer;
                              out upc_ret: integer32;
                              out usb_ret: integer32;
                              out usp_ret: integer32);
  options(extern, val_param);

{ PROC1_$INHIBIT_BEGIN and PROC1_$INHIBIT_END (hand assembly in
  PROC1_ASM, ml/m68k/exclusion.s): enter and leave an inhibited
  region. }
procedure proc1_$inhibit_begin; extern;
procedure proc1_$inhibit_end; extern;

