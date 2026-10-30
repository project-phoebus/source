{ proc2/proc2.ins.pas - PROC2_$ (process management) routines, for the
  Domain Pascal tree.

  The constants, types, variables and headings of PROC2 that the Pascal
  files use: the PROC2 module's own (proc2/proc2.pas) and those its
  users call.  Each heading follows both sides of the call.

  Include base/base.ins.pas before it.
}

{ PROC2_$SIGNAL_PGROUP_OS - send a signal to a process group for the
  system, with no permission check. }
procedure proc2_$signal_pgroup_os(pgroup_uid: uid_$t; signal: integer;
                                  param: status_$t;
                                  out status_ret: status_$t); extern;

{ PROC2_$UPGID_TO_UID - the UID of a UNIX process group id. }
procedure proc2_$upgid_to_uid(in upgid: integer; out uid_ret: uid_$t;
                              out status_ret: status_$t); extern;

{ PROC2_$GET_MY_UPIDS - return the current process's UNIX ids. }
procedure proc2_$get_my_upids(out upid_ret: integer; out uppid_ret: integer;
                              out upgid_ret: integer); extern;

{ PROC2_$SIGNAL_OS: four arguments by address, the default convention.
  Unlike PROC2_$SIGNAL_PGROUP_OS it copies none of its first two: the
  UID's slot is passed on and the signal word read through its slot at
  each use; param is read once into a frame longword at entry and read
  again through the slot later, which a value parameter would not be
  (its later reads go to the copy), so the frame longword is a local
  (proc2/signal_os.pas).  None of the three is written: `in'.  The
  status is stored at the end and not read: `out'.  Callers:
  TIME_$SET_ITIMER_REAL_CALLBACK and three more in TIME_UNWIRED (an
  element of PROC2_$UID), ASKNODE_$INTERNET_INFO (the signal a constant
  cell), and DXM_$ADD_SIGNAL_CALLBACK through its table (DXM_WIRED_,
  dxm/add_signal_callback.pas).  The names are the other tree's; param's
  type as PROC2_$SIGNAL_PGROUP_OS's, a status. }
{ PROC2_$SIGNAL_OS - send a signal to a process for the system, with no
  permission check. }
procedure proc2_$signal_os(in proc_uid: uid_$t; in signal: integer;
                           in param: univ status_$t;
                           out status_ret: status_$t); extern;

var
  { PROC2_$UID (map symbol, in PROC2's .DATA block, proc2/proc2.pas): the
    UIDs of the processes by address space, 58 of them, 8-byte elements
    from 0.  Other units index it from its symbol
    (DXM_$ADD_SIGNAL_CALLBACK, TIME_$SET_ITIMER_REAL_CALLBACK). }
  proc2_$uid: extern array[0..57] of uid_$t;

{ PROC2_$GET_PID - the PROC1 pid of a process UID. }
function proc2_$get_pid(in proc_uid: uid_$t; out status_ret: status_$t): integer;
  extern;

{ PROC2_$DELETE - delete the current process; proc2_$delete_cleanup. }
procedure proc2_$delete; extern;

type
  { The fault status a stopped process carries (an entry's fault_param):
    a status longword whose bit 23, the top bit of status_$t's modc
    (base/base.ins.pas), is a flag of its own (the "signal flag" of
    fim/fim.ins.pas fim_blast_signal_status), set and cleared alone on
    its second byte (XPD_$RESTART; XPD_$GET_REGISTERS on a copy): a
    boolean field of a packed record.  The other variant is the
    longword, as status_$t's `all'.  Declared here, not in
    proc2/proc2_data.ins.pas, for PROC2_$DELIVER_FIM's heading. }
  proc2_$fault_param_t = packed record
    case integer of
      1: (all: integer32);                { 0x00 }
      2: (high_byte: 0..255;              { 0x00 }
          signal_flag: boolean;           { 0x01, bit 7 }
          unused_bits: 0..127;            { 0x01, bits 6..0 }
          code: integer);                 { 0x02 }
  end;

  { The register save area and the SR/PC record of a fault (the other
    tree's fault_context and fault_frame).  PROC2_$DELIVER_FIM takes
    their addresses by value (its heading below); the register block's
    type stays for xpd/xpd.ins.pas's xpd_$regs_ptr_t, and nothing uses
    the SR/PC array. }
  proc2_$fault_regs_t = array[1..16] of integer32;
  proc2_$fault_frame_t = array[1..3] of integer;

{ PROC2_$DELIVER_FIM - pick the signal FIM is to deliver to the current
  process. }
function proc2_$deliver_fim(in out signal: integer;
                            in out status: univ proc2_$fault_param_t;
                            in out usp: integer32;
                            regs: univ_ptr;
                            sr_pc: univ_ptr;
                            out mask: integer32;
                            out flag: boolean): boolean;
  options(extern, val_param);

{ PROC2_$SET_CLEANUP - flag a cleanup handler for the calling process. }
procedure proc2_$set_cleanup(handler_bit: integer); options(extern, val_param);

{ PROC2_$UPID_TO_UID - the UID of a UNIX process id. }
procedure proc2_$upid_to_uid(in upid: integer; out uid_ret: uid_$t;
                             out status_ret: status_$t);
  extern;


{ PROC2_$FIND_INDEX - the process-table index of a process UID. }
function proc2_$find_index(proc_uid: uid_$t; out status_ret: status_$t): integer;
  extern;

{ PROC2_$FIND_ASID - the address space of a process UID. }
function proc2_$find_asid(in proc_uid: uid_$t; in use_alt: boolean;
                          out status_ret: status_$t): integer;
  extern;

{ PROC2_$AWAKEN_GUARDIAN - wake a process's guardian (its debugger, or
  else its parent). }
procedure proc2_$awaken_guardian(in proc_index: pinteger); extern;

{ PROC2_$GET_ASID - the address space of a process UID. }
function proc2_$get_asid(in proc_uid: uid_$t; out status_ret: status_$t):
  integer;
  extern;


const
  { Apollo's customer proc2.ins.pas line 11, `proc2_$uid_not_found =
    16#00190001'.  NAME_$READ_DIRS_PS and XPD_$RESTART store it when no
    process has the UID. }
  proc2_$uid_not_found = 16#00190001;

{ PROC2_$GET_DEBUGGER_PID - the PROC1 pid of the caller's debugger. }
function proc2_$get_debugger_pid: pinteger; extern;

{ PROC2_$SHUTDOWN - suspend every other bound process. }
procedure proc2_$shutdown; extern;

{ PROC2_$INIT's mode, a word set: the body tests its members in the
  word's low byte, the member test of a word set in memory (dpc gives
  exactly that for `0 in s').  Member 0 boots from tape (TAPE_$BOOT),
  member 1 from floppy (FLOP_$BOOT); OS_$INIT passes 0 or 2 on the SAU2,
  and on the SAUs with tape_boot also [0] and [0, 1] (os/init.pas). }
type
  proc2_$ws_mode_t = set of 0..15;
const
  proc2_$boot_from_tape = 0;
  proc2_$boot_from_floppy = 1;

{ PROC2_$INIT - set up the level-2 process table and process 1, and find
  process 2's program. }
function proc2_$init(in ws_mode: univ proc2_$ws_mode_t;
                     out status: status_$t): univ_ptr;
  extern;

{ The PROC2_ routines ASKNODE_$INTERNET_INFO calls, in map order.

  The buffers they fill: a list of process UIDs (at most 16#39, the
  clamp below) and PROC2_$INFO's and PROC2_$GET_INFO's information
  block, copied byte by byte up to the caller's length or 16#E4:
  `univ', so that the callers' own buffers pass. }
type
  proc2_$uid_list_t = array[1..57] of uid_$t;
  proc2_$info_buf_t = array[1..228] of char;

{ PROC2_$LIST - list the UIDs of the level-2 processes. }
procedure proc2_$list(out uid_list: univ proc2_$uid_list_t;
                      in max_count: pinteger;
                      out count: pinteger); extern;

{ PROC2_$LIST2 - list the UIDs of the level-2 processes from a start
  index.
  PROC2_$ZOMBIE_LIST - list the UIDs of the zombie processes from a start
  index. }
procedure proc2_$list2(out uid_list: univ proc2_$uid_list_t;
                       in max_count: pinteger;
                       out count: pinteger;
                       in start_index: integer32;
                       out more: boolean;
                       out next_index: integer32); extern;
procedure proc2_$zombie_list(out uid_list: univ proc2_$uid_list_t;
                             in max_count: pinteger;
                             out count: pinteger;
                             in start_index: integer32;
                             out more: boolean;
                             out next_index: integer32); extern;

{ PROC2_$INFO - the combined PROC1/PROC2 information block for an ASID. }
procedure proc2_$info(in scan_key: integer;
                      in pid: integer;
                      out info: univ proc2_$info_buf_t;
                      in info_len: pinteger;
                      out status_ret: status_$t); extern;


{ PROC2_$GET_INFO - the combined PROC1/PROC2 information block for a
  process UID. }
procedure proc2_$get_info(proc_uid: uid_$t;
                          out info: univ proc2_$info_buf_t;
                          in info_len: pinteger;
                          out status_ret: status_$t); extern;

{ PROC2_$GET_UPIDS - return a process's UNIX ids. }
procedure proc2_$get_upids(proc_uid: uid_$t;
                           out upid: pinteger;
                           out uppid: pinteger;
                           out upgid: pinteger;
                           out status_ret: status_$t); extern;

{ PROC2's own routines (proc2/proc2.pas) and what they and their users
  need, in map order. }

const
  { PROC2's status codes (the SR10.2 status-code database's texts,
    subsystem 16#19; the other tree's names where Apollo's customer
    proc2.ins.pas has none: it names only 16#00190001..16#00190004). }
  { "(19000a) invalid process name": PROC2_$SET_NAME and
    PROC2_$NAME_TO_UID store it for a length outside 0..32. }
  status_$proc2_invalid_process_name = 16#0019000A;
  { "(190009) another fault is pending for this process":
    proc2_$deliver_signal_internal stores it for a second SIGAPOLLO. }
  status_$proc2_another_fault_pending = 16#00190009;
  { "(19000e) process is a zombie": PROC2_$SIGNAL takes it from
    PROC2_$FIND_INDEX as a found target.  "(190012) permission denied":
    PROC2_$SIGNAL stores it for a signal it may not send.  "Process is
    not a debug target" and "permission denied" XPD stores too. }
  status_$proc2_zombie = 16#0019000E;
  status_$proc2_proc_not_debug_target = 16#00190010;
  status_$proc2_permission_denied = 16#00190012;

  { The process's cleanup handler bits, members of an entry's
    cleanup_flags (proc2/proc2_data.ins.pas proc2_$cleanup_set_t): the
    subsystem whose per-process state a dying process must release.  The
    subsystems set them through PROC2_$SET_CLEANUP (NET_$OPEN 10,
    MSG_$OPEN and MSG_$ALLOCATE 7, PCHIST_$UNIX_PROFIL_CNTL 11,
    TIME_$SET_ITIMER 6), and PROC2's cleanup routine tests each and
    calls the subsystem's release (proc2/cleanup_handlers_internal.pas).
    The names follow the routine each bit selects. }
  proc2_$cleanup_lpr = 1;                 { LPR_$RELEASE }
  proc2_$cleanup_mt = 2;                  { MT_$RELEASE }
  proc2_$cleanup_ct = 3;                  { CT_$RELEASE }
  proc2_$cleanup_pbu = 4;                 { PBU_$FREE_ASID }
  proc2_$cleanup_disk = 5;                { DISK_$UNASSIGN_ALL }
  proc2_$cleanup_time = 6;                { TIME_$RELEASE }
  proc2_$cleanup_msg = 7;                 { MSG_$FREE_ASID }
  proc2_$cleanup_gpu = 9;                 { GPU_$TERM }
  proc2_$cleanup_net_io = 10;             { NET_IO_$FREE_ASID }
  proc2_$cleanup_pchist = 11;             { PCHIST_$UNIX_PROFIL_CNTL }
  proc2_$cleanup_scsi = 12;               { SCSI_$FREE_ASID }
  proc2_$cleanup_mac_os = 13;             { MAC_OS_$PROC2_CLEANUP }
  proc2_$cleanup_xns_idp = 14;            { XNS_IDP_$PROC2_CLEANUP }

  { Signal numbers, Apollo's (the SR10.2 install tree's BSD signal
    list; the other tree's own list is 4.3BSD's, which numbers them
    otherwise).  PROC2_$AWAKEN_GUARDIAN sends the guardian SIGCLD and
    SIGCHLD. }
  proc2_$sig_cld = 18;                    { SIGCLD, "death of a child" }
  proc2_$sig_chld = 23;                   { SIGCHLD, "to parent on child
                                            stop or exit" }
  { The signals proc2_$deliver_signal_internal compares with. }
  proc2_$sig_hup = 1;                     { SIGHUP, "hangup" }
  proc2_$sig_quit = 3;                    { SIGQUIT, "quit": PROC2_$QUIT's
                                            constant }
  proc2_$sig_kill = 9;                    { SIGKILL, "kill (cannot be
                                            caught or ignored)" }
  proc2_$sig_apollo = 19;                 { SIGAPOLLO, "Apollo-specific
                                            fault" }
  proc2_$sig_cont = 22;                   { SIGCONT, "continue a stopped
                                            process" }

  { Signal sets, a signal's member being its number less 1
    (proc2_$deliver_signal_internal's `[signal - 1]').  The stop
    signals, SIGSTOP 20, SIGTSTP 21, SIGTTIN 24 and SIGTTOU 25: SIGCONT
    takes them out of the pending set, and a signal among them is tested
    with the same mask, the complement's set (`x * c' of a held value).
    The signals 4.3BSD ignores by default and Apollo's SIGCLD: SIGCLD
    18, SIGCONT 22, SIGCHLD 23, SIGIO 26, SIGURG 31 and SIGWINCH 32,
    members 17, 21, 22, 25, 30, 31, tested by the complement's mask. }
  proc2_$stop_signals = [19, 20, 23, 24];
  proc2_$not_stop_signals = [0..31] - proc2_$stop_signals;
  proc2_$default_ignored_signals = [17, 21, 22, 25, 30, 31];
  proc2_$not_default_ignored_signals =
    [0..31] - proc2_$default_ignored_signals;
  { The fault signals SIGILL 4, SIGTRAP 5 and SIGFPE 8 PROC2_$DELIVER_FIM
    may leave pending, tested by the complement's mask on the set's low
    word. }
  proc2_$fault_signals = [3, 4, 7];
  proc2_$not_fault_signals = [0..31] - proc2_$fault_signals;

type
  { A process name, up to 32 characters (an entry's name):
    PROC2_$SET_NAME copies the caller's from element 1, and
    PROC2_$NAME_TO_UID compares the same way. }
  proc2_$name_t = array[1..32] of char;

var
  { P2_INFO_ALLOC_PTR (map symbol, in PROC2's .DATA block,
    proc2/proc2.pas): the head of the list of allocated process entries,
    a table index (0 for none).  PROC2_$NAME_TO_UID multiplies it
    signed: integer. }
  p2_info_alloc_ptr: extern integer;

{ PROC2_$SET_NAME - name a process. }
procedure proc2_$set_name(in proc_name: univ proc2_$name_t;
                          in proc_name_len: integer;
                          in proc_uid: uid_$t;
                          out status_ret: status_$t); extern;

{ PROC2_$NAME_TO_UID - find a process by its name. }
procedure proc2_$name_to_uid(in proc_name: univ proc2_$name_t;
                             in proc_name_len: integer;
                             out uid_ret: uid_$t;
                             out status_ret: status_$t); extern;

{ PROC2_$SIGNAL - send a signal to a process. }
procedure proc2_$signal(proc_uid: uid_$t; in signal: integer;
                        param: univ status_$t;
                        out status_ret: status_$t); extern;

{ PROC2_$QUIT - send a process SIGQUIT with the quit fault status. }
procedure proc2_$quit(in proc_uid: uid_$t; out status_ret: status_$t);
  extern;


const
  { SIGSTOP, "sendable stop signal not from tty" (Apollo's, as the
    signals above): PROC2_$ACKNOWLEDGE tests its member. }
  proc2_$sig_stop = 20;

  { The statuses PROC2_$ACKNOWLEDGE posts with a signal: the SR10.2
    status-code database's "(9010009) process kill fault" and
    "(9010017) child status has changed fault", 16#09010000 plus SIGKILL
    and SIGCHLD (xpd/xpd.ins.pas xpd_signal_status_base).  No customer
    insert file names them. }
  status_$proc2_kill_fault = 16#09010009;
  status_$proc2_child_changed_fault = 16#09010017;

type
  { A signal set, a signal's member being its number less 1 (as the sets
    above; proc2/proc2_data.ins.pas's entry fields are sets of 0..31 of
    their own, assignment compatible with it). }
  proc2_$sig_set_t = set of 0..31;

  { What PROC2_$ACKNOWLEDGE returns, two longwords: the blocked set now
    in effect, and 1 or 0 for the entry's flag 10; PROC2_$SIGRETURN
    returns the same two.  Flag 10 marks a signal taken on the signal
    stack (proc2/proc2_data.ins.pas sig_mask_3). }
  proc2_$sig_state_t = record
    blocked: proc2_$sig_set_t;            { 0x00 }
    on_sigstack: integer32;               { 0x04 }
  end;

{ PROC2_$SIGNAL_PGROUP - send a signal to a process group, with the
  permission check. }
procedure proc2_$signal_pgroup(pgroup_uid: uid_$t; signal: integer;
                               param: status_$t;
                               out status_ret: status_$t); extern;

{ PROC2_$ACKNOWLEDGE - acknowledge a signal's delivery to the current
  process. }
procedure proc2_$acknowledge(in new_blocked: proc2_$sig_set_t;
                             in signal: integer;
                             out result: proc2_$sig_state_t); extern;

{ PROC2_$DELIVER_PENDING - deliver the current process's pending signals. }
procedure proc2_$deliver_pending; extern;


type
  { The two blocked sets of a process entry (proc2/proc2_data.ins.pas
    proc2_info_t's sig_blocked) as one record: PROC2_$GET_SIG_MASK copies
    the pair whole into its output record, dpc's code for an 8-byte
    record assignment (asknode's SMD display record, smd/smd.ins.pas
    smd_$disp_dims_t, the same shape), where each other field is a
    longword move of its own.  The field names are the other tree's. }
  proc2_$sig_blocked_t = record
    blocked_1: proc2_$sig_set_t;          { 0x00 }
    blocked_2: proc2_$sig_set_t;          { 0x04 }
  end;

{ PROC2_$SIGRETURN - return from a user signal handler. }
procedure proc2_$sigreturn(in context: univ_ptr;
                           in regs: univ_ptr;
                           in fp_state: univ_ptr;
                           out result: proc2_$sig_state_t); extern;

{ PROC2_$SIGBLOCK - add signals to the current process's blocked set. }
function proc2_$sigblock(in mask: proc2_$sig_set_t;
                         out result: proc2_$sig_state_t): proc2_$sig_set_t;
  extern;

{ PROC2_$SIGSETMASK - replace the current process's blocked set. }
function proc2_$sigsetmask(in mask: proc2_$sig_set_t;
                           out result: proc2_$sig_state_t):
  proc2_$sig_set_t; extern;

type
  { What PROC2_$GET_SIG_MASK returns (the other tree's field names and
    offsets): the entry's blocked pair copied whole
    (proc2_$sig_blocked_t, above), five more signal sets copied a
    longword each, and two flags stored as booleans, at their odd and
    even byte offsets (a boolean may lie at an odd offset).  flag_1 is
    the entry's flags member 10 (on_sig_stack), flag_2 member 2
    (no_cld_stop; proc2/proc2_data.ins.pas proc2_$flags_t).  The record
    is 16#20 bytes: PROC2_$SET_SIG_MASK takes two of them by value and
    copies each in as 8 longwords, where a 16#1E-byte record would copy
    7 longwords and a word; PROC2_$GET_SIG_MASK leaves the last word
    alone (unused_1e; the other tree's record ends at 16#1E). }
  proc2_$sig_mask_t = record
    blocked: proc2_$sig_blocked_t;        { 0x00 }
    pending: proc2_$sig_set_t;            { 0x08 }
    mask_1: proc2_$sig_set_t;             { 0x0C }
    mask_2: proc2_$sig_set_t;             { 0x10 }
    mask_3: proc2_$sig_set_t;             { 0x14 }
    mask_4: proc2_$sig_set_t;             { 0x18 }
    flag_1: boolean;                      { 0x1C }
    flag_2: boolean;                      { 0x1D }
    unused_1e: integer;                   { 0x1E }
  end;

{ PROC2_$GET_SIG_MASK - return the current process's signal state. }
procedure proc2_$get_sig_mask(out mask_ret: proc2_$sig_mask_t); extern;

{ PROC2_$SET_SIG_MASK - change the current process's signal state. }
procedure proc2_$set_sig_mask(in priority_delta: integer;
                              clear_mask: proc2_$sig_mask_t;
                              set_mask: proc2_$sig_mask_t;
                              out result: proc2_$sig_state_t); extern;


{ PROC2_$SIGPAUSE - install a temporary blocked set and wait for a signal. }
procedure proc2_$sigpause(in new_mask: proc2_$sig_set_t;
                          out result: proc2_$sig_state_t); extern;

const
  { The options of PROC2_$WAIT, members of its options word
    (proc2_$wait_options_t, below), 4.3BSD wait4's (Apollo's BSD
    include file: WNOHANG 1, "dont hang in wait", and WUNTRACED 2,
    "tell about stopped, untraced children"), as members 0 and 1: PROC2_$WAIT
    returns 0 at once under the first, proc2_$wait_try_live_child
    reports a stopped child only under the second.  The names follow
    Apollo's. }
  proc2_$wait_nohang = 0;
  proc2_$wait_untraced = 1;

  { The low byte of a stopped child's wait status (Apollo's BSD include
    file's WSTOPPED 8#177, "value of s.stopval if process is stopped"), or-ed
    under the stop signal shifted up 8 (proc2_$wait_try_live_child,
    proc2_$wait_try_zombie).  The name follows Apollo's. }
  proc2_$wait_stopped = 8#177;

  { The SR10.2 status-code database's "(19000d) wait found no children",
    PROC2_$WAIT's status.  No customer insert file names it; the other
    tree's name. }
  status_$proc2_wait_found_no_children = 16#0019000D;

type
  { PROC2_$WAIT's options word (above): a word set, its slot read once
    and its members tested in a register. }
  proc2_$wait_options_t = set of 0..15;

  { The 14 longwords a zombie keeps in its entry (zombie_counts) and
    PROC2_$WAIT returns at the start of its result, copied whole (dpc's
    code for a 56-byte assignment), and the 20-byte usage record after
    them.

    The 14 longwords are the process's resource counters as it dies:
    proc2_$delete_cleanup copies them from the creation record's first
    block, adds two PROC1_$STATS counters to the sixth and eighth, and,
    for a process that was not vforked, the record's second block,
    longword by longword.  What each holds is not settled.

    The usage record's first six bytes are a clock:
    proc2_$build_info_internal copies the record whole into its block
    for a zombie (dpc's code for a 20-byte record assignment is the
    array's), and the clock alone into the PROC1 half's cpu.total; for a
    live process it fills the same 20 bytes field by field:
    PROC1_$GET_ANY_CPU_USAGE's clock and its two longwords, the constant
    16#411C, the word after the clock never written (the null block
    clears all but that word).  The last 12 bytes are one object: the
    cleanup copies them from the creation record as a block (dpc's code
    for a 12-byte record assignment), after updating the record's copy
    field by field; proc2_$build_info_internal clears them as a run.  So
    they are a nested record, proc2_$usage_counts_t.  The field names:
    cpu_time, then PROC1_$GET_ANY_CPU_USAGE's stat2_ret and
    stat1_ret (proc1/proc1.ins.pas), in their order in the record.
    Every field access is the same code. }
  proc2_$wait_data_t = array[1..14] of integer32;
  proc2_$usage_counts_t = record
    stat2: integer32;                     { 0x00 }
    stat1: integer32;                     { 0x04 }
    field_10: integer32;                  { 0x08 }
  end;
  proc2_$wait_usage_t = record
    cpu_time: time_$clock_t;              { 0x00 }
    pad_06: integer;                      { 0x06 }
    counts: proc2_$usage_counts_t;        { 0x08 }
  end;

  { A child's exit report, two longwords (the other tree's exit_status
    and exit_info): copied whole from a zombie's entry
    (proc2_$wait_reap_child, proc2_$wait_try_zombie; dpc's code for an
    8-byte assignment), and for a stopped child built field by field:
    the status, the entry's fault parameter with its signal flag cleared
    alone: the second longword is a proc2_$fault_param_t (above). }
  proc2_$exit_t = record
    status: integer32;                    { 0x00 }
    info: proc2_$fault_param_t;           { 0x04 }
  end;

  { What PROC2_$WAIT returns, 16#68 bytes (the other tree's offsets and
    field names but exit's pair): built in PROC2_$WAIT's frame by its two
    helpers and copied out whole (26 longwords, dpc's code for a
    16#68-byte assignment).  The child's parent's UID or UID_$NIL, its
    own UID, three booleans, the last byte not written. }
  proc2_$wait_result_t = record
    entry_60: proc2_$wait_data_t;         { 0x00 }
    parent_uid: uid_$t;                   { 0x38 }
    child_uid: uid_$t;                    { 0x40 }
    exit: proc2_$exit_t;                  { 0x48 }
    usage: proc2_$wait_usage_t;           { 0x50 }
    flag_64: boolean;                     { 0x64 }
    flag_65: boolean;                     { 0x65 }
    flag_66: boolean;                     { 0x66 }
    unused_67: char;                      { 0x67 }
  end;

{ PROC2_$WAIT - wait for a child to stop or die (4.3BSD wait4). }
function proc2_$wait(in options: proc2_$wait_options_t;
                     in pid: integer;
                     out result: proc2_$wait_result_t;
                     out status_ret: status_$t): integer; extern;


const
  { "(19000b) bad eventcount key" (the SR10.2 status-code database; the
    other tree's name): PROC2_$GET_EC stores it for a key other than
    0. }
  status_$proc2_bad_eventcount_key = 16#0019000B;

{ PROC2_$GET_EC - register a process's signal-delivery eventcount with
  EC2. }
procedure proc2_$get_ec(in proc_uid: uid_$t;
                        in key: integer;
                        out ec_ret: univ_ptr;
                        out status_ret: status_$t); extern;

{ PROC2_$GET_CR_REC - the creation record's UIDs from an EC2 handle. }
procedure proc2_$get_cr_rec(in ec_handle: univ_ptr;
                            out parent_uid: uid_$t;
                            out proc_uid: uid_$t;
                            out status_ret: status_$t); extern;

{ PROC2_$LIST_PGROUP - list the UIDs of a process group's members. }
procedure proc2_$list_pgroup(in pgroup_uid: uid_$t;
                             out uid_list: univ proc2_$uid_list_t;
                             in max_count: pinteger;
                             out count: pinteger); extern;


const
  { Apollo's customer proc2.ins.pas, lines 12 and 14, `proc2_$not_level_2
    = 16#00190002;' and `proc2_$is_current = 16#00190004;', with the
    comment "info request is for current" (the SR10.2 status-code
    database: "(190002) not a level two process", "(190004) request is
    for current process"): proc2_$build_info_internal stores them, the
    first for an entry neither bound nor a zombie, the second for the
    caller's own PROC1 process. }
  proc2_$not_level_2 = 16#00190002;
  proc2_$is_current = 16#00190004;
  { The SR10.2 status-code database's "(190013) internal error" and
    "(190014) process is already an orphan", the other tree's names:
    PROC2_$MAKE_ORPHAN crashes with the first when the sibling chain
    ends before the process, and stores the second for a process with no
    parent. }
  status_$proc2_internal_error = 16#00190013;
  status_$proc2_already_orphan = 16#00190014;

{ PROC2_$MY_PID - the calling process's PROC1 pid. }
function proc2_$my_pid: pinteger; extern;

{ PROC2_$MAKE_ORPHAN - detach a process from its parent. }
procedure proc2_$make_orphan(proc_uid: uid_$t;
                             out status_ret: status_$t); extern;


const
  { The SR10.2 status-code database's "(190017) attempted to join a
    process group in a different session", the other tree's name:
    PROC2_$SET_PGROUP and proc2_$pgroup_set_internal store it. }
  status_$proc2_pgroup_in_different_session = 16#00190017;

{ PROC2_$UID_TO_UPID - the UNIX process id of a process UID. }
procedure proc2_$uid_to_upid(proc_uid: uid_$t; out upid_ret: integer;
                             out status_ret: status_$t); extern;

{ PROC2_$PGUID_TO_UPGID - the UNIX group id of a process-group UID. }
procedure proc2_$pguid_to_upgid(pgroup_uid: uid_$t;
                                out upgid_ret: pinteger;
                                out status_ret: status_$t); extern;

{ PROC2_$SET_PGROUP - move a process into a process group (setpgid). }
procedure proc2_$set_pgroup(proc_uid: uid_$t; in new_upgid: integer;
                            out status_ret: status_$t); extern;


const
  { The SR10.2 status-code database's "(190005) suspend request timed
    out", "(190006) process not suspended" and "(190007) process already
    suspended", the other tree's names.  PROC2_$SUSPEND stores the
    first, and its nested proc2_$suspend_try the third for PROC1's
    "already suspended"; PROC2_$RESUME stores the second for PROC1's "not
    suspended". }
  status_$proc2_suspend_timed_out = 16#00190005;
  status_$proc2_not_suspended = 16#00190006;
  status_$proc2_already_suspended = 16#00190007;

{ PROC2_$SUSPEND - suspend a process. }
procedure proc2_$suspend(in proc_uid: uid_$t; out status_ret: status_$t);
  extern;

{ PROC2_$RESUME - resume a suspended process. }
procedure proc2_$resume(in proc_uid: uid_$t; out status_ret: status_$t);
  extern;

{ PROC2_$SET_SERVER - set or clear a process's server flag. }
procedure proc2_$set_server(in proc_uid: uid_$t; server_flag: boolean;
                            out status_ret: status_$t); extern;

{ PROC2_$SET_STACK_TRUNC_SIZE - an empty entry point. }
procedure proc2_$set_stack_trunc_size; extern;

{ PROC2_$SET_PRIORITY - set a process's priority range. }
procedure proc2_$set_priority(in proc_uid: uid_$t;
                              in priority_1: pinteger;
                              in priority_2: pinteger;
                              out status_ret: status_$t); extern;

{ ---- PROC2's debug routines. ---- }

const
  { "(190011) process is already a debug target" (the SR10.2 status-code
    database): PROC2_$DEBUG stores it when the target has a debugger.
    The other tree's name. }
  status_$proc2_process_already_debugging = 16#00190011;

{ PROC2_$DEBUG - make the caller the debugger of a process.
  PROC2_$OVERRIDE_DEBUG - make the caller the debugger of a process,
  whatever debugger it has.
  PROC2_$UNDEBUG - detach the caller from a process it debugs. }
procedure proc2_$debug(in proc_uid: uid_$t; out status_ret: status_$t);
  extern;
procedure proc2_$override_debug(in proc_uid: uid_$t;
                                out status_ret: status_$t); extern;
procedure proc2_$undebug(in proc_uid: uid_$t; out status_ret: status_$t);
  extern;

{ ---- The accounting, boot-flag, debugger, TTY, session and CPU-usage
  routines. ---- }

const
  { "(190015) process is a process group leader" and "(190016) another
    process is using this process group id" (the SR10.2 status-code
    database): PROC2_$SET_SESSION_ID stores them.  The other tree's
    names. }
  status_$proc2_process_is_group_leader = 16#00190015;
  status_$proc2_process_using_pgroup_id = 16#00190016;

type
  { The accounting text PROC2_$SET_ACCT_INFO copies into an entry's
    acct_info (32 characters), a byte at a time from the caller's array:
    a char array indexed from 1. }
  proc2_$acct_info_t = array[1..32] of char;

{ PROC2_$SET_ACCT_INFO - record the calling process's accounting data. }
procedure proc2_$set_acct_info(in info: univ proc2_$acct_info_t;
                               in info_len: integer;
                               in acct_uid: uid_$t;
                               out status_ret: status_$t); extern;

{ PROC2_$GET_BOOT_FLAGS - return the boot flags word. }
procedure proc2_$get_boot_flags(out flags_ret: integer); extern;

{ PROC2_$GET_TTY_DATA - the caller's TTY UID and session id. }
procedure proc2_$get_tty_data(out tty_uid: uid_$t;
                              out tty_flags: integer); extern;

{ PROC2_$SET_TTY - record the caller's controlling TTY. }
procedure proc2_$set_tty(in new_tty_uid: uid_$t); extern;

{ PROC2_$SET_SESSION_ID - put the calling process into a session. }
procedure proc2_$set_session_id(allow_leader: boolean;
                                new_session: integer;
                                out status_ret: status_$t); extern;

{ PROC2_$GET_CPU_USAGE - the calling process's CPU usage. }
procedure proc2_$get_cpu_usage(out usage: proc2_$wait_usage_t); extern;

{ ---- The alignment-control, register and process-group-information
  routines. ---- }

{ PROC2_$ALIGN_CTL - alignment control: a stub that clears its outputs. }
procedure proc2_$align_ctl(in param_1: integer32; in param_2: integer32;
                           out result_1: pinteger;
                           out result_2: integer32;
                           out status_ret: status_$t); extern;

{ PROC2_$GET_REGS - a process's registers: a stub that refuses. }
procedure proc2_$get_regs(in proc_uid: uid_$t; in arg2: integer32;
                          in arg3: integer32; in arg4: integer32;
                          in arg5: integer32;
                          out status_ret: status_$t); extern;

{ PROC2_$PGROUP_INFO - a process group's session and leader state. }
procedure proc2_$pgroup_info(in pgroup_id: integer;
                             out session_id_ret: pinteger;
                             out is_leader_ret: boolean;
                             out status_ret: status_$t); extern;


{ ---- For PROC2_$CREATE and proc2_$init_entry_internal. ---- }

const
  { The SR10.2 status-code database's "(19000f) no entries in level 2
    process table": PROC2_$CREATE stores it when the free list is empty.
    The other tree's name. }
  status_$proc2_table_full = 16#0019000F;

type
  { The record PROC2_$STARTUP starts a new process from (the other
    tree's startup context, past its first longword): PROC2_$STARTUP
    reads the ASID from it and passes the whole on to FIM_$PROC2_STARTUP
    by address, which takes the first two longwords as the user stack
    pointer and the program counter (fim/fim.ins.pas
    fim_$startup_context_t, its usp and its program counter).
    PROC2_$CREATE fills it.  10 bytes.  The field names are fim_$startup_context_t's and the
    other tree's (asid). }
  proc2_$startup_args_t = record
    usp: integer32;                       { 0x00 }
    pc: integer32;                        { 0x04 }
    asid: integer;                        { 0x08 }
  end;

  { The context PROC2_$CREATE builds below a new process's stack (14
    bytes): PROC1_$BIND is given its address as the initial stack
    pointer, and its first longword holds the address of the record
    after it: the argument slot PROC2_$STARTUP finds (its heading,
    below).  The longword is formed in integer arithmetic from the
    context's address, linteger as that address (PROC2_$CREATE's ctx).
    The other tree's self_ptr. }
  proc2_$startup_context_t = record
    self_ptr: linteger;                   { 0x00 }
    args: proc2_$startup_args_t;          { 0x04 }
  end;
  proc2_$startup_context_ptr_t = ^proc2_$startup_context_t;

{ PROC2_$STARTUP - the first routine of a new process. }
procedure proc2_$startup(in context: proc2_$startup_args_t); extern;

{ PROC2_$CREATE - create a new process. }
procedure proc2_$create(in parent_uid: uid_$t;
                        in code_desc: integer32;
                        in map_param: integer32;
                        in entry_point: integer32;
                        in user_data: integer32;
                        in reserved1: integer32;
                        in reserved2: integer32;
                        in init_flag: boolean;
                        out uid_ret: uid_$t;
                        out ec_ret: univ_ptr;
                        out status_ret: status_$t); extern;


{ PROC2_$SET_VALID - mark the current process valid at its start. }
procedure proc2_$set_valid; extern;

{ PROC2_$FORK - fork the calling process. }
procedure proc2_$fork(in entry_point: integer32;
                      in user_data: integer32;
                      in fork_flags: integer32;
                      out uid_ret: uid_$t;
                      in reserved: integer32;
                      out upid_ret: integer;
                      out ec_ret: univ_ptr;
                      out status_ret: status_$t); extern;


{ PROC2_$WHO_AM_I - return the current process's UID. }
procedure proc2_$who_am_i(out puid: uid_$t); extern;

{ PROC2_$COMPLETE_FORK - tell the parent that the forked child runs. }
procedure proc2_$complete_fork; extern;

const
  { The SR10.2 status-code database's "(19000c) attempt to complete
    vfork on non-vforked process": PROC2_$COMPLETE_VFORK stores it when
    the caller's entry lacks member 11 (alt_asid).  The other tree's
    name. }
  status_$proc2_process_wasnt_vforked = 16#0019000C;

{ PROC2_$COMPLETE_VFORK - give a vforked child its own address space. }
procedure proc2_$complete_vfork(in proc_uid: uid_$t;
                                in code_desc: integer32;
                                in map_param: integer32;
                                in entry_point: integer32;
                                in user_data: integer32;
                                in reserved1: integer32;
                                in reserved2: integer32;
                                out status_ret: status_$t); extern;
