{ proc2/proc2_data.ins.pas - PROC2's process table, its process-group
  table and its per-process eventcounts, for the Domain Pascal tree.

  Declares the objects of PROC2's data that other units address directly
  (XPD, OS, PROC2 itself), so that their layout is written down once.  It
  is kept apart from proc2/proc2.ins.pas (the routine headings, included
  by many modules) because it declares an overlay section (below), which
  only the units that reach the tables need.  Include base/base.ins.pas,
  ec/ec.ins.pas and proc2/proc2.ins.pas before it.
}

const
  { The members of an entry's flags word (proc2_$flags_t, below), for
    the set view's member tests and stores; the names are the boolean
    view's.  The zombie member. }
  proc2_pf_zombie = 13;

  { The saved-mask member, set by PROC2_$SIGPAUSE and tested and cleared
    by PROC2_$DELIVER_FIM, and the signal-stack member. }
  proc2_pf_mask_saved = 14;
  proc2_pf_on_sig_stack = 10;
  { The init member, the word's top bit, tested by the word's sign, and
    the stopped member.  The XPD members are xpd/xpd.ins.pas's
    (xpd_pf_suspended, xpd_pf_state_saved). }
  proc2_pf_init = 15;
  proc2_pf_stopped = 6;
  { The bound member.  With xpd/xpd.ins.pas's xpd_pf_debug_target
    (member 7) it makes a valid process; PROC2_$LIST and
    PROC2_$LIST_PGROUP take member 7 alone for a listed process. }
  proc2_pf_bound = 8;
  { The alternate-ASID member (the other tree also names it the vfork
    member). }
  proc2_pf_alt_asid = 11;
  { The server member, stored as a boolean in
    proc2_$build_info_internal's record. }
  proc2_pf_server = 9;
  { The orphan and debug members. }
  proc2_pf_orphan = 12;
  proc2_pf_debug = 3;
  { Member 2, the boolean view's no_cld_stop: no SIGCHLD to the parent
    for a stop.  PROC2_$CREATE clears it with members 10, 11 and 12. }
  proc2_pf_no_cld_stop = 2;

type
  { The per-process ptrace options, 14 bytes of a process entry (XPD's
    field names).  PROC2_$FORK copies them whole.  The two flag bytes
    are sets of 0..7, packed so that each takes its byte (ref 3.9.3
    p. 3-16, small sets in a packed record; in an unpacked record a set
    takes at least a word, pkt/pkt.ins.pas): their members are tested
    in place, cleared whole and widened to a word for a run-time member
    (the widening of a packed small set to an unpacked one).
    signal_mask is a 32-member set tested with a run-time member.  The
    range bounds are compared unsigned with a PC: linteger (a linteger
    field of a packed record keeps its 32 bits, word aligned, as dpc
    lays it out). }
  proc2_$ptrace_opts_t = packed record
    signal_mask: set of 0..31;            { 0x00 }
    trace_range_lo: linteger;             { 0x04 }
    trace_range_hi: linteger;             { 0x08 }
    flags: set of 0..7;                   { 0x0C }
    flags2: set of 0..7;                  { 0x0D }
  end;

  { proc2_$fault_param_t, the fault status a stopped process carries,
    is declared in proc2/proc2.ins.pas, for PROC2_$DELIVER_FIM's
    heading, whose status is of that type. }

  { The PROC2 flags word, a word set.  The image tests and sets single
    members on its low byte, clears several at once on the word, and
    tests a member above 7 on the word loaded.  The members XPD uses are
    named in xpd/xpd.ins.pas.  A variant record with two views of the
    word, each the one whose code an access compiles to (as
    prom/prom.ins.pas prom_$machine_id_t).  `bits' is the set: member
    tests, `+ [n]' / `- [n]', several members at once, and run-time
    members.  The booleans are the same word as 16 one-bit fields, high
    bit first (dpc allocates a packed record's fields from the word's
    top bit), for the stores of a boolean value into a member, as
    PROC2_$SIGRETURN's.

    Names: Apollo's are not known.  init, zombie, orphan, alt_asid (also
    the vfork member), server, bound and debug are the other tree's;
    debug_target, state_saved, suspended and trace_pending are XPD's;
    the rest are named from what the routines do with them: mask_saved
    (14, sigpause's saved mask is pending, 4.3BSD's SOMASK;
    PROC2_$DELIVER_FIM), on_sig_stack (10, 4.3BSD's sigstack ss_onstack;
    PROC2_$SIGRETURN, PROC2_$GET_SIG_MASK), stopped (6, set by a stop
    signal, cleared by SIGCONT; PROC2_$ACKNOWLEDGE,
    proc2_$deliver_signal_internal), no_cld_stop (2, no SIGCHLD to the
    parent for a stop, Apollo's SV_NOCLDSTOP, 16#0004;
    PROC2_$ACKNOWLEDGE, PROC2_$SET_SIG_MASK), and unused_0 (no access
    seen). }
  proc2_$flags_t = packed record
    case integer of
      1: (bits: set of 0..15);            { 0x00 }
      2: (init: boolean;                  { bit 15 }
          mask_saved: boolean;            { bit 14 }
          zombie: boolean;                { bit 13 }
          orphan: boolean;                { bit 12 }
          alt_asid: boolean;              { bit 11 }
          on_sig_stack: boolean;          { bit 10 }
          server: boolean;                { bit 9 }
          bound: boolean;                 { bit 8 }
          debug_target: boolean;          { bit 7 }
          stopped: boolean;               { bit 6 }
          state_saved: boolean;           { bit 5 }
          suspended: boolean;             { bit 4 }
          debug: boolean;                 { bit 3 }
          no_cld_stop: boolean;           { bit 2 }
          trace_pending: boolean;         { bit 1 }
          unused_0: boolean);             { bit 0 }
  end;

  { The cleanup handler bits of an entry (the members are named in
    proc2/proc2.ins.pas, proc2_$cleanup_lpr and the rest), a word set
    as proc2_$flags_t: PROC2's cleanup routine tests members 0..7 on the
    word's low byte in place and the members above 7 on the word loaded
    (a word set's members). }
  proc2_$cleanup_set_t = set of 0..15;

  { The accounting UID and the word after it, ten bytes of an entry and
    of proc2_$build_info_internal's record: copied as ten characters (a
    byte loop is a char array's copy) and cleared as a UID and a word:
    one object with two views.  The word is the length of acct_info. }
  proc2_$acct_id_t = record
    case integer of
      1: (uid: uid_$t;                    { 0x00 }
          info_len: pinteger);            { 0x08 }
      2: (chars: array[1..10] of char);   { 0x00 }
  end;

  { The flags word of a dead entry (the zombie view below):
    PROC2_$WAIT's helpers test its members 15 and 14 into their
    result's two booleans (the set view), and proc2_$delete_cleanup
    stores the two bits from the creation record's two boolean bytes:
    stores of packed booleans from a value, the code of
    proc2_boot_flags_t's (proc2/proc2.pas; dpc's for `b := x' on a
    packed record's first and second booleans).  One word, two views.
    What the two bits mean is not known. }
  proc2_zombie_flags_t = packed record
    case integer of
      1: (bits: set of 0..15);            { 0x00 }
      2: (flag_15: boolean;               { bit 15 }
          flag_14: boolean;               { bit 14 }
          unused_bits: 0..16383);         { bits 13..0 }
  end;

  { A process entry, 16#E4 bytes (not Apollo's proc2_$info_t of the
    customer proc2.ins.pas, which is PROC2_$GET_INFO's output record;
    the field names are the other tree's unless noted).  Every field is
    typed from how the routines use it.

    - The signal masks are 32-member sets, tested and extended with
      run-time members (XPD_$CAPTURE_FAULT).  The two blocked sets are
      one record field, sig_blocked (proc2/proc2.ins.pas
      proc2_$sig_blocked_t: PROC2_$GET_SIG_MASK copies the pair whole).
    - pad_18's two words are integer: PROC2_$SET_SIG_MASK adds the delta
      to the first and compares both signed with the word.
    - self_index, debugger_idx and level1_pid are pinteger: entries are
      indexed by them with an unsigned multiply, they are compared with
      the pinteger PID-to-index table, and level1_pid goes by address
      where PROC1_$CURRENT (pinteger) does too (XPD_$READ_PROC_ASYNC).
    - pad_94 is the event code and signal word (XPD_$CAPTURE_FAULT),
      read signed (XPD_$RESTART): integer.
    - state_va and last_pc are two longwords named after XPD's: the
      debug-state record's address while the process is stopped
      (XPD_$CAPTURE_FAULT, XPD_$RESTART) and the PC it last stopped at.
      fault_param, state_va and last_pc are longwords at 2 mod 4, word
      aligned (`[aligned(1)]', ref 3.10.6).
    - pad_bf and pad_c0, three bytes at an odd offset, are a char and a
      two-char array: an array longer than a byte is word aligned (ref
      3.10.5.5), which would move fault_param by a byte.
    - session_id is integer: twice it is widened signed against the
      process-group table's pinteger session_id, which is widened
      unsigned (PROC2_$SET_PGROUP, proc2_$pgroup_set_internal): the
      widening of an `integer' and a `0..65535' operand to 32 bits for
      their compare (ref 4.3.3; dpc compiles it the same).  Its other
      uses compare it with itself or with 0, or clear it, the same code
      for either type; against upid it is a word compare, two integers.
    - upid is integer: it is widened signed (PROC2_$SET_VALID) and
      compared as a word with integers (the session_id above, the
      `in integer' ids of PROC2_$UPID_TO_UID and PROC2_$SET_PGROUP,
      PROC2_$WAIT's target, the integer proc2_$next_upid), where an
      integer/pinteger compare is widened; dpc gives exactly that code
      for an integer field.  No access zero-extends it or compares it
      unsigned.
    - creation_time is one clock: proc2_$delete_cleanup passes its
      address to PACCT_$LOG's `in start_clock: time_$clock_t', and
      PROC2_$CREATE and PROC2_$FORK store its halves, the same code
      either way (their statements name the fields).  time_$clock_t is
      an `[aligned(1)]' packed record (base/base.ins.pas), so it stays
      at 16#56.

    The zombie view (arm 2) is what proc2_$delete_cleanup leaves for
    PROC2_$WAIT:
    - zombie_counts, the 14 resource counters (proc2/proc2.ins.pas
      proc2_$wait_data_t, the note there), copied from the creation
      record's first block, and added to;
    - zombie_exit: its status and its fault word from the creation
      record;
    - zombie_flags: two packed booleans from the record's two bytes
      (proc2_zombie_flags_t, above);
    - zombie_usage: the CPU time (the record's clock for a vforked
      child, else the record's after ADD48 adds the child's),
      PROC1_$GET_CPU_USAGE's two longwords, the constant 16#411C, and
      for a child that was not vforked the record's counts;
    - zombie_pad_a2: nothing writes it.
    The meaning of the counters, the flags and the exit status beyond
    that is not known. }
  proc2_info_t = record
    uid: uid_$t;                          { 0x00 }
    parent_uid: uid_$t;                   { 0x08 }
    pgroup_table_idx: pinteger;           { 0x10 }
    next_index: pinteger;                 { 0x12 }
    pad_14: pinteger;                     { 0x14 }
    upid: integer;                        { 0x16 }
    pad_18: array[1..2] of integer;       { 0x18 }
    self_index: pinteger;                 { 0x1C }
    parent_pgroup_idx: pinteger;          { 0x1E }
    first_child_idx: pinteger;            { 0x20 }
    next_child_sibling: pinteger;         { 0x22 }
    first_debug_target_idx: pinteger;     { 0x24 }
    debugger_idx: pinteger;               { 0x26 }
    next_debug_target_idx: pinteger;      { 0x28 }
    flags: proc2_$flags_t;                { 0x2A }
    acct_info: array[1..32] of char;      { 0x2C }
    acct: proc2_$acct_id_t;               { 0x4C: the account UID and its
                                            length }
    creation_time: time_$clock_t;         { 0x56 }
    session_id: integer;                  { 0x5C }
    pad_5e: pinteger;                     { 0x5E }
    case integer of
      { the entry of a live process (and the fields a zombie keeps) }
      1: (tty_uid: uid_$t;                      { 0x60 }
          cr_rec: integer32;                    { 0x68 }
          cr_rec_2: integer32;                  { 0x6C }
          sig_pending: set of 0..31;            { 0x70 }
          sig_blocked: proc2_$sig_blocked_t;    { 0x74: sig_blocked_1 and
                                                  sig_blocked_2 }
          sig_mask_3: set of 0..31;             { 0x7C }
          sig_mask_2: set of 0..31;             { 0x80 }
          sig_mask_1: set of 0..31;             { 0x84 }
          pad_88: integer32;                    { 0x88 }
          sig_mask_4: set of 0..31;             { 0x8C }
          sig_status: integer32;                { 0x90 }
          pad_94: integer;                      { 0x94 }
          asid: integer;                        { 0x96 }
          asid_alt: integer;                    { 0x98 }
          level1_pid: pinteger;                 { 0x9A }
          cleanup_flags: proc2_$cleanup_set_t;  { 0x9C }
          name: array[1..32] of char;           { 0x9E }
          name_len: char;                       { 0xBE }
          pad_bf: char;                         { 0xBF }
          pad_c0: array[1..2] of char;          { 0xC0 }
          fault_param: [aligned(1)] proc2_$fault_param_t;  { 0xC2 }
          state_va: [aligned(1)] univ_ptr;      { 0xC6 }
          last_pc: [aligned(1)] linteger;       { 0xCA }
          ptrace_opts: proc2_$ptrace_opts_t;    { 0xCE }
          stack_uid: uid_$t);                   { 0xDC }
      { a zombie's exit report, as proc2_$delete_cleanup writes it }
      2: (zombie_counts: proc2_$wait_data_t;  { 0x60 }
          zombie_exit: proc2_$exit_t;     { 0x98 }
          zombie_flags: proc2_zombie_flags_t;  { 0xA0: the word set with a
                                                 boolean view }
          zombie_pad_a2: integer;         { 0xA2 }
          zombie_usage: proc2_$wait_usage_t);  { 0xA4 }
  end;

  { A pointer to an entry: PROC2_$SIGNAL holds two, the caller's and
    the target's entries' addresses formed once, and reads both
    entries' fields through them (proc2/signal.pas). }
  proc2_info_ptr_t = ^proc2_info_t;

  { A process's eventcount pair, 16#18 bytes. }
  proc2_ec_entry_t = record
    fork_ec: ec_$eventcount_t;            { 0x00 }
    cr_rec_ec: ec_$eventcount_t;          { 0x0C }
  end;

  { A process-group entry, 8 bytes (the other tree's names and
    offsets): the reference count, the count of group leaders, the UNIX
    process group id and the session id. }
  proc2_pgroup_entry_t = record
    ref_count: integer;                   { 0x00 }
    leader_count: integer;                { 0x02 }
    upgid: pinteger;                      { 0x04 }
    session_id: pinteger;                 { 0x06 }
  end;

var
  { PROC2_$EC: one eventcount pair per process-table slot, 70 of them
    from 1 (the whole of the hand-written data block PROC2_WIRED_ASM,
    16#690 bytes; map symbol). }
  proc2_$ec: extern array[1..70] of proc2_ec_entry_t;

{ PROC2_$DATA (map symbol, 16#4168 bytes): a load section with no
  module segment in it, an overlay section (ref 3.14 p. 3-52; 7.2.4,
  Method 4; pchist/pchist.pas's PCHIST_UNWIRED_D), reached only by its
  absolute address and displacements.

  The process entries from 1, 70 of them, 16#E4 bytes each; the routines
  form element idx's address and reach its fields at displacements less
  16#E4.  Then 16#5E bytes nothing reaches, and the PID-to-index table
  from 0, indexed by PROC1_$CURRENT, 65 words.  Then the process-group
  table (below).

  The process table is proc2_$info_table: the map names the routine
  PROC2_$INFO, and the map's names win; the array has no map symbol of
  its own (the map's PROC2_$DATA is the section). }
var (proc2_$data)
  proc2_$info_table: array[1..70] of proc2_info_t;          { +0x0000 }
  proc2_unused_3e58: array[1..94] of char;             { +0x3E58 }
  proc2_$pid_to_index: array[0..64] of pinteger;       { +0x3EB6 }
  { The process-group table, from 1 to the section's end (16#3F38 +
    70 * 8 = 16#4168, the map size): element 0 would overlay the PID
    table's last four words, and is never used as a group
    (pgroup_find_by_upgid returns 1..69, or 0 for none). }
  proc2_$pgroup_table: array[1..70] of proc2_pgroup_entry_t;  { +0x3F38 }
