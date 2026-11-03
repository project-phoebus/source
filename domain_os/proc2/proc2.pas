{ proc2/proc2.pas - the PROC2 module, the level-2 process manager.

  Image addresses:
    sau2  0x00E35030  PROC2 data (OS_INIT_DATA, 4 bytes)
    sau2  0x00E7BE84  PROC2 data (.DATA, 0x1E8 bytes)
    sau2  0x00E86050  PROC2 data (PROC2_CREATE_DAT, 4 bytes)
    sau2  0x00E8605C  PROC2 data (PROC2_DELETE_DAT, 4 bytes)

  One compilation unit, `module proc2;': PROC2_$INIT in OS_INIT_PROC,
  the bulk in .TEXT, PROC2_$CREATE .. PROC2_$GET_MY_UPIDS in
  PROC2_CREATE_PRO, PROC2_$DELETE in PROC2_DELETE_PRO, each headed with
  its sections; the three small blocks are 4 zero bytes (TODO below).

  PROC2_WIRED_ASM (PROC2_$EC, hand-written data) and the overlay
  PROC2_$DATA (the process, PID and process-group tables) are declared
  in proc2/proc2_data.ins.pas.

  The .DATA block, zero but proc2_$next_upid:
    +0x000  proc2_$proc_dir_uid    8 bytes
    +0x008  proc2_$system_uid      8 bytes
    +0x010  PROC2_$UID             58 * 8 bytes from 0 (defined)
    +0x1E0  P2_INFO_ALLOC_PTR      2 bytes, the allocated list (defined)
    +0x1E2  proc2_$free_list_head  2 bytes

    +0x1E4  proc2_$boot_flags      2 bytes
    +0x1E6  proc2_$next_upid       2 bytes, 65, the next UNIX process id

  The routines live in one fragment file each (proc2/<name>.pas),
  included below in image order; proc2/README.md has the table.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/proc2/proc2.pas.  Check: tools/pascal_check.sh.
}
module proc2;

{ TODO(pascal) the three 4-byte data blocks and the A5 loads into them

  The OS_INIT_DATA, PROC2_CREATE_DAT and PROC2_DELETE_DAT blocks are all
  zero, and nothing reads or writes them: no object of the source that
  this module can name.  The same open point as acl/acl.pas's and
  xpd/xpd.pas's (the cause not known).  Until it is settled the module
  declares nothing for them.

  - OS_INIT_DATA: PROC2_$INIT loads A5 with the block's end and never
    uses it (its data are reached through their absolute addresses,
    proc2/init.pas).  So the block holds no object of INIT's: A5 is
    loaded with the block's end as every routine of a section with a
    data partner loads it.
  - PROC2_CREATE_DAT: PROC2_$WHO_AM_I, PROC2_$GET_UPIDS and
    PROC2_$GET_MY_UPIDS load A5 with the block's end and use it for
    nothing; PROC2_$CREATE, proc2_$init_entry_internal,
    PROC2_$SET_VALID, PROC2_$COMPLETE_FORK and PROC2_$COMPLETE_VFORK
    load no A5.  The block's end is the start of ACL_'s block, whose own
    routines in the section load the end of theirs: each module's A5 is
    its own block's end.
  - PROC2_DELETE_DAT: PROC2_$DELETE loads A5 and uses it for nothing
    (proc2/delete.pas); proc2_$delete_cleanup loads none.  But
    PROC2_$DELETE's A5 is the block's start, not its end: the end of the
    block before it, FILE_'s (FILE_'s routines in PROC2_CREATE_PRO load
    the same value), where ACL_'s and FILE_'s routines in
    PROC2_DELETE_PRO load their own blocks' ends.  The one exception to
    "each module's A5 is its own block's end" in these sections.

  Still open: why the compiler emits a 4-byte block that no object
  needs, and why PROC2_$DELETE's A5 is 4 bytes short.  dpc cannot
  reproduce the unused A5 loads (`--a5-always' refuses a unit with no
  data in the routine's data section), and loads no A5 for a routine
  with no data (its PROC2_$DELETE has none). }

%include 'base/base.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'uid/uid.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'mst/mst.ins.pas';
%include 'fim/fim.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'proc2/proc2_data.ins.pas';
%include 'acl/acl.ins.pas';
%include 'audit/audit.ins.pas';
%include 'os/os.ins.pas';
%include 'peb/peb.ins.pas';
%include 'xpd/xpd.ins.pas';
%if lpr_driver %then
%include 'cbuf/cbuf.ins.pas';
%endif
%include 'lpr/lpr.ins.pas';
%include 'pbu/pbu.ins.pas';
%include 'mt/mt.ins.pas';
%include 'ct/ct.ins.pas';
%include 'disk/disk.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'sock/sock.ins.pas';
%include 'net_io/net_io.ins.pas';
%include 'route/route.ins.pas';
%include 'rip/rip.ins.pas';
%include 'msg/msg.ins.pas';
%include 'gpu/gpu.ins.pas';
%include 'pchist/pchist.ins.pas';
%include 'scsi/scsi.ins.pas';
%include 'mac_os/mac_os.ins.pas';
%include 'xns/xns.ins.pas';
%include 'xns/xns_idp.ins.pas';
%include 'as/as.ins.pas';
%include 'dtty/dtty.ins.pas';
%include 'tape/tape.ins.pas';
%include 'flop/flop.ins.pas';
%include 'name/name.ins.pas';
%include 'file/file.ins.pas';
%include 'cal/cal.ins.pas';
%include 'smd/smd.ins.pas';
%include 'dma/dma.ins.pas';
%include 'suma/suma.ins.pas';
%include 'term/term.ins.pas';
%include 'pacct/pacct.ins.pas';
%include 'rem_name/rem_name.ins.pas';
%include 'dir/dir.ins.pas';

const
  { proc2_$log_signal_event's event types, the audit event UID's top
    byte: a signal to a process (PROC2_$SIGNAL passes 1) or to a process
    group (PROC2_$SIGNAL_PGROUP passes 2; the routine reads the group
    table for it). }
  proc2_signal_event_process = 1;
  proc2_signal_event_pgroup = 2;

  { The two values of an entry's name_len that are not a name's length,
    proc2_$delete_cleanup's case labels: no name at all (PROC2_$INIT and
    proc2_$init_entry_internal store it) and a name set empty, which the
    process directory then knows by the process's UID (PROC2_$SET_NAME
    stores it for a zero length). }
  proc2_name_len_none = chr(16#21);
  proc2_name_len_by_uid = chr(16#22);

  { DIR_$DIR_READU's max_entries and buf_size as proc2_$delete_cleanup
    passes them, by address, from the two constant cells after its
    code: one entry of 16#36 bytes (proc2_dirent_t, below).  The other
    tree's names. }
  proc2_$delete_dirent_max = 1;
  proc2_$delete_dirent_size = 54;

type
  { The audit record proc2_$log_signal_event builds (the other tree's
    names): the event UID, then the ten bytes of data logged, the
    signal's parameter, the target's address space (0 for a group), the
    signal and the target's UNIX id.  Stored field by field, the data
    passed from the record's byte 8. }
  proc2_signal_audit_event_t = record
    event_uid: uid_$t;                    { 0x00 }
    param: status_$t;                     { 0x08 }
    asid: integer;                        { 0x0C }
    signal: integer;                      { 0x0E }
    upid: pinteger;                       { 0x10 }
  end;

  { A view of one PROC1_$STATS record (proc1/proc1.ins.pas
    proc1_$stats_t, four longwords, which that file declares as one
    array): proc2_$build_info_internal copies its first longword alone
    and the other three as one 12-byte block: two objects, a longword
    and 12 bytes. }
  proc2_stats_view_t = record
    first: integer32;                     { 0x00 }
    rest: array[1..3] of integer32;       { 0x04 }
  end;

  { The information block proc2_$build_info_internal fills, 16#E4 bytes,
    which PROC2_$INFO and PROC2_$GET_INFO copy out up to the caller's
    length (the other tree's field names and offsets; not Apollo's
    customer proc2_$info_t, an older and smaller record).  Every offset
    is a displacement off the block's address, and dpc gives each one
    and the size.  The types are from the accesses:
    - proc1_info, PROC1_$GET_INFO's record (proc1/proc1.ins.pas), whose
      address goes to it, and whose cpu.total takes a zombie's clock;
    - sid, ACL_$GET_PID_SID's block (acl/acl.ins.pas acl_sid_block_t:
      four UIDs and a longword);
    - min_priority and max_priority, PROC1_$SET_PRIORITY's two `var'
      integers;
    - server_flag, a boolean;
    - cpu_time, proc2_stats_view_t (above);
    - pgroup_flags, upid, parent_upid, pgroup_info and session_upid,
      words from pinteger fields and from proc2_$entry_pgroup_upgid's
      `out' pinteger; asid an integer from the entry's;
    - acct, the entry's ten-byte proc2_$acct_id_t
      (proc2/proc2_data.ins.pas), copied as characters, cleared as a UID
      and a word;
    - acct_info and name, 32-character arrays copied by bytes;
    - name_len a word set to 0, -1 or the entry's character: integer;
    - usage, proc2_$wait_usage_t (proc2/proc2.ins.pas), a zombie's
      copied whole;
    - pad_51 and pad_ce, never written. }
  proc2_combined_info_t = record
    parent_uid: uid_$t;                   { 0x00 }
    cr_rec: integer32;                    { 0x08 }
    proc1_info: proc1_$info_t;            { 0x0C }
    sid: acl_sid_block_t;                 { 0x24 }
    proc_uid_2: uid_$t;                   { 0x48 }
    server_flag: boolean;                 { 0x50 }
    pad_51: char;                         { 0x51 }
    min_priority: integer;                { 0x52 }
    max_priority: integer;                { 0x54 }
    cpu_time: proc2_stats_view_t;         { 0x56 }
    pgroup_uid: uid_$t;                   { 0x66 }
    pgroup_flags: pinteger;               { 0x6E }
    upid: pinteger;                       { 0x70 }
    parent_upid: pinteger;                { 0x72 }
    pgroup_info: pinteger;                { 0x74 }
    session_upid: pinteger;               { 0x76 }
    asid: integer;                        { 0x78 }
    acct: proc2_$acct_id_t;               { 0x7A }
    acct_info: array[1..32] of char;      { 0x84 }
    name_len: integer;                    { 0xA4 }
    name: array[1..32] of char;           { 0xA6 }
    tty_uid: uid_$t;                      { 0xC6 }
    pad_ce: integer;                      { 0xCE }
    usage: proc2_$wait_usage_t;           { 0xD0 }
  end;

  { The process group's UID as proc2_$entry_pgroup_uid builds it: a zero
    word, the group's UNIX id, a zero longword, or UID_$NIL whole: a UID
    with a word view.  The third view, the UID's first byte as a number:
    proc2_$uid_to_upgid_internal widens it to a word and tests it, its
    zero telling a group's UID (built here and by
    proc2_$upgid_to_uid_internal) from a process's; then reads the word
    view.  proc2_$upgid_to_uid_internal builds the UID from UID_$NIL and
    the word. }
  proc2_uid_byte_t = [byte] 0..255;
  proc2_pgroup_uid_view_t = record
    case integer of
      1: (uid: uid_$t);                   { 0x00 }
      2: (zero: integer;                  { 0x00 }
          upgid: pinteger;                { 0x02 }
          low: integer32);                { 0x04 }
      3: (first_byte: proc2_uid_byte_t);  { 0x00 }
  end;

  { The process's creation record in its own address space, reached
    through the entry's cr_rec_2 (a user virtual address held as a
    longword), as PROC2_$SET_VALID and PROC2_$COMPLETE_VFORK fill it and
    the dying process (proc2_$delete_cleanup) reads it; the other tree's
    offsets, which the image's displacements confirm, and its names
    where it has them.  debug_setup_internal and debug_clear_internal
    pass XPD_$WRITE the address of debug_flag, with one byte of 16#FF on
    attaching a debugger and 0 on detaching it.
    - block_1, block_2: two blocks of fourteen longwords
      (proc2/proc2.ins.pas's proc2_$wait_data_t), each cleared by a loop
      of its own: two arrays, each the whole object of its loop.
      block_1 is copied whole to the zombie's counters, an assignment
      that needs one named type on both sides; block_2 is added to them
      element by element.
    - exit_status: copied to the zombie's exit status.
    - cpu_time: a clock, ADD48's `in out' first argument, then copied to
      the zombie's usage as a longword and a word; PROC2_$SET_VALID's
      two clears name its halves (the same code).
    - counts: proc2/proc2.ins.pas's proc2_$usage_counts_t, copied out as
      one 12-byte block after its fields are updated one by one;
      PROC2_$SET_VALID's run of three clears names its fields (a run of zero
      stores cleared as one block).
    - flag_88, flag_89: two booleans whose bytes are read whole and
      stored as one bit each in the zombie's flags
      (proc2/proc2_data.ins.pas proc2_zombie_flags_t).
    - vfork_time: a clock, set from the CPU time and copied to the
      zombie's usage for a vforked child; time_$clock_t is an
      `[aligned(1)]' packed record (base/base.ins.pas), so it sits at
      16#8A.
    - debug_flag: cleared, then set from a test: a boolean.
    - status: MST_$MAP_AREA_AT's out status, tested whole.
    - proc_uid, parent_uid, stack_uid: UIDs copied as two longwords.
    - addr_lo, size: AS_$INFO's stack file address and size stored, and
      passed on to MST_$MAP_AREA_AT's two `in' longwords.
    - upid_b8: the entry's upid widened: integer32.
    - debugger_uid: a UID copied from PROC2_$UID.
    - unused_c4: a byte no routine reaches; flags_c5: a byte whose bit 3
      is tested in place: a `[byte] set of 0..7' (an unpacked record's
      plain small set takes a word).
    - count_c6: a word set to 1.
    - b_c8: a byte cleared; a byte subrange (no test says boolean).
    The record ends there as far as the image shows (16#C9 bytes; dpc
    pads it to 16#CC, its longword alignment); no routine copies it
    whole.  dpc gives every offset (`addr' of every field). }
  proc2_cr_rec_t = record
    block_1: proc2_$wait_data_t;          { 0x00 }
    block_2: proc2_$wait_data_t;          { 0x38 }
    exit_status: integer32;               { 0x70 }
    cpu_time: time_$clock_t;              { 0x74 }
    pad_7a: integer;                      { 0x7A }
    counts: proc2_$usage_counts_t;        { 0x7C }
    flag_88: boolean;                     { 0x88 }
    flag_89: boolean;                     { 0x89 }
    vfork_time: time_$clock_t;            { 0x8A }
    debug_flag: boolean;                  { 0x90 }
    pad_91: char;                         { 0x91 }
    pad_92: integer;                      { 0x92 }
    status: status_$t;                    { 0x94 }
    proc_uid: uid_$t;                     { 0x98 }
    parent_uid: uid_$t;                   { 0xA0 }
    stack_uid: uid_$t;                    { 0xA8 }
    addr_lo: integer32;                   { 0xB0 }
    size: integer32;                      { 0xB4 }
    upid_b8: integer32;                   { 0xB8 }
    debugger_uid: uid_$t;                 { 0xBC }
    unused_c4: char;                      { 0xC4 }
    flags_c5: [byte] set of 0..7;         { 0xC5 }
    count_c6: integer;                    { 0xC6 }
    b_c8: [byte] 0..255;                  { 0xC8 }
  end;
  proc2_cr_rec_ptr_t = ^proc2_cr_rec_t;

  { The first ten bytes of /sys/boot_shell, which PROC2_$INIT copies out
    of a read-only mapping as one 10-byte object: the address the shell
    is mapped at, passed by address to MST_$MAP_AT's `in' va; the entry
    PC, the routine's result; and a word no routine reads. }
  proc2_boot_shell_hdr_t = record
    map_va: integer32;                    { 0x00 }
    entry_pc: integer32;                  { 0x04 }
    w_08: integer;                        { 0x08 }
  end;
  proc2_boot_shell_hdr_ptr_t = ^proc2_boot_shell_hdr_t;

  { The six bytes PROC2_$INIT leaves at the top of the init process's
    stack, at AS_$STACK_HIGH - 6: the boot flags' word and a zero
    longword. }
  proc2_boot_stack_t = record
    flags: integer;                       { 0x00 }
    zero: integer32;                      { 0x02 }
  end;
  proc2_boot_stack_ptr_t = ^proc2_boot_stack_t;

  { The boot flags' word (the .DATA block's proc2_$boot_flags):
    PROC2_$GET_BOOT_FLAGS and PROC2_$INIT read it whole; PROC2_$INIT
    keeps its top two bits, the `&' of the word, and stores bit 15 from
    MMU_$NORMAL_MODE's boolean and bit 14 from the negation of
    DTTY_$USE_DTTY: packed boolean fields stored from a value (dpc gives
    the image's code for `b := x' on a packed record's first and second
    booleans).  A word with a boolean view. }
  proc2_boot_flags_t = packed record
    case integer of
      1: (w: integer);                    { 0x00 }
      2: (normal_mode: boolean;           { bit 15 }
          no_dtty: boolean;               { bit 14 }
          unused_bits: 0..16383);         { bits 13..0 }
  end;

  { One DIR_$DIR_READU entry as proc2_$delete_cleanup reads it from its
    16#36-byte buffer (the other tree's names and offsets): the UID,
    compared with the entry's, the name's length and the name, passed to
    DIR_$DROPU: an `in' integer and a `univ' name.  The other bytes are
    not read.  16#36 bytes (dpc
    gives the size). }
  proc2_dirent_t = record
    unused_00: integer32;                 { 0x00 }
    uid: uid_$t;                          { 0x04 }
    unused_0c: array[1..2] of integer32;  { 0x0C }
    name_len: integer;                    { 0x14 }
    name: array[1..32] of char;           { 0x16 }
  end;

{ PROC1_$SUSPEND_EC (map symbol in the hand-written PROC1_ASM;
  proc1/proc1.pas declares it the same way): PROC2_$SUSPEND reads its
  value and passes its address to EC_$WAIT.  Declared here, not in
  proc1/proc1.ins.pas, for the reason proc1.pas gives (that insert needs
  no ec/ec.ins.pas); another unit's variable, so no storage here. }
var
  proc1_$suspend_ec: extern ec_$eventcount_t;

{ DIR_$DIR_READU: the heading dir/dir.pas declares for itself (its
  evidence there; not in dir/dir.ins.pas, because its continuation is
  rem_name/rem_name.ins.pas's), copied unchanged: proc2_$delete_cleanup
  passes its nine addresses.  Two copies until the heading has one home
  (the README's open items). }
procedure dir_$dir_readu(in dir_uid: uid_$t;
                         in out name: univ name_$long_name_t;
                         in out name_len: pinteger;
                         in out continuation: rem_name_$continuation_t;
                         in max_entries: integer32;
                         in buf_size: integer32;
                         var buf: univ dir_$readu_buf_t;
                         out count_ret: linteger;
                         out status_ret: status_$t);
  extern;

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above). }
var
  proc2_$proc_dir_uid: uid_$t;                       { +0x000, zero }
  proc2_$system_uid: uid_$t;                         { +0x008, zero }

define
  proc2_$uid;                                        { +0x010, zero }
  p2_info_alloc_ptr;                                 { +0x1E0, zero }

var
  proc2_$free_list_head: integer;                    { +0x1E2, zero }
  proc2_$boot_flags: proc2_boot_flags_t;             { +0x1E4, zero }
  proc2_$next_upid: integer := 16#41;                { +0x1E6: 0041 }

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  proc2_$init;
  proc2_$awaken_guardian;
  proc2_$set_name;
  proc2_$name_to_uid;
  proc2_$deliver_fim;
  proc2_$signal;
  proc2_$signal_os;
  proc2_$quit;
  proc2_$signal_pgroup;
  proc2_$signal_pgroup_os;
  proc2_$acknowledge;
  proc2_$deliver_pending;
  proc2_$sigreturn;
  proc2_$sigblock;
  proc2_$sigsetmask;
  proc2_$get_sig_mask;
  proc2_$set_sig_mask;
  proc2_$sigpause;
  proc2_$wait;
  proc2_$get_ec;
  proc2_$get_cr_rec;
  proc2_$list_pgroup;
  proc2_$list;
  proc2_$list2;
  proc2_$zombie_list;
  proc2_$find_index;
  proc2_$get_asid;
  proc2_$find_asid;
  proc2_$info;
  proc2_$get_info;
  proc2_$my_pid;
  proc2_$get_pid;
  proc2_$make_orphan;
  proc2_$upid_to_uid;
  proc2_$uid_to_upid;
  proc2_$upgid_to_uid;
  proc2_$pguid_to_upgid;
  proc2_$set_pgroup;
  proc2_$suspend;
  proc2_$resume;
  proc2_$set_server;
  proc2_$set_stack_trunc_size;
  proc2_$set_priority;
  proc2_$set_cleanup;
  proc2_$shutdown;
  proc2_$debug;
  proc2_$override_debug;
  proc2_$undebug;
  proc2_$set_acct_info;
  proc2_$get_boot_flags;
  proc2_$get_debugger_pid;
  proc2_$get_tty_data;
  proc2_$set_tty;
  proc2_$set_session_id;
  proc2_$get_cpu_usage;
  proc2_$align_ctl;
  proc2_$get_regs;
  proc2_$pgroup_info;
  proc2_$create;
  proc2_$fork;
  proc2_$startup;
  proc2_$set_valid;
  proc2_$complete_fork;
  proc2_$complete_vfork;
  proc2_$who_am_i;
  proc2_$get_upids;
  proc2_$get_my_upids;
  proc2_$delete;

{ Forward headings of module-local routines called before their bodies. }

{ proc2_$deliver_signal_internal, called before its body by
  PROC2_$AWAKEN_GUARDIAN: four slots by value, two words, a longword and
  the status's address; the body clears the status at entry: `out'.
  The other tree's names. }
{ body: proc2/deliver_signal_internal.pas }
procedure proc2_$deliver_signal_internal(proc_index: integer;
                                         signal: integer;
                                         param: status_$t;
                                         out status_ret: status_$t);
  forward; internal;

{ proc2_$deliver_pending_internal, called before its body by
  proc2_$deliver_signal_internal: one word slot by value after the pad,
  the index.  The other tree's name. }
{ body: proc2/deliver_pending_internal.pas }
procedure proc2_$deliver_pending_internal(proc_index: integer);
  forward; internal;

{ proc2_$get_next_pending_signal, called before its body by
  proc2_$deliver_pending_internal and PROC2_$DELIVER_FIM: one slot, the
  entry's address (a record by address under internal), read and never
  written: `in'; the result a word.  The other tree's name. }
{ body: proc2/get_next_pending_signal.pas }
function proc2_$get_next_pending_signal(in entry: proc2_info_t): integer;
  forward; internal;

{ proc2_$uid_to_pgroup_index, called before its body by
  PROC2_$SIGNAL_PGROUP and PROC2_$SIGNAL_PGROUP_OS: one slot, the UID's
  address (a record by address under internal), only read: `in'.  The
  UID is `univ' proc2_pgroup_uid_view_t: the body reads its first byte
  and its second word, the views proc2_$uid_to_upgid_internal reads
  (below), and passes the whole on to PROC2_$FIND_INDEX; `univ' leaves
  the callers' uid_$t arguments as they are.  The result is integer: it
  holds either pgroup_find_by_upgid's integer or the entry's pinteger
  index, and the callers only test it and push it.  The other tree's
  names. }
{ body: proc2/uid_to_pgroup_index.pas }
function proc2_$uid_to_pgroup_index(
           in pgroup_uid: univ proc2_pgroup_uid_view_t): integer;
  forward; internal;

{ proc2_$detach_from_parent, called before its body by
  PROC2_$SET_SIG_MASK: two word slots by value, the child's index and
  its previous sibling's (no pad: the two words fill a longword).  The
  other tree's names. }
{ body: proc2/detach_from_parent.pas }
procedure proc2_$detach_from_parent(child_idx: integer;
                                    prev_sibling_idx: integer);
  forward; internal;

{ debug_setup_internal, called before its body by PROC2_$DEBUG and
  PROC2_$OVERRIDE_DEBUG, after it by PROC2_$CREATE and PROC2_$FORK:
  three word slots by value after the pad, the boolean in its slot's
  high byte; the body passes the first slot's address on.  The other
  tree's names. }
{ body: proc2/debug_setup_internal.pas }
procedure debug_setup_internal(target_idx: integer; debugger_idx: integer;
                               flag: boolean);
  forward; internal;

{ debug_clear_internal, called before its body by
  proc2_$wait_reap_child and proc2_$wait_try_zombie: two word slots by
  value, the index and a boolean (no pad: the two words fill a
  longword), the boolean in its slot's high byte.  The other tree's
  names. }
{ body: proc2/debug_clear_internal.pas }
procedure debug_clear_internal(proc_idx: integer; flag: boolean);
  forward; internal;

{ pgroup_set_internal, called before its body by PROC2_$SET_PGROUP and
  PROC2_$SET_SESSION_ID, after it by proc2_$init_entry_internal (from
  PROC2_CREATE_PRO): the entry by address, a word by value and the
  status's address, after the pad.  The body writes the entry: `var';
  tests the word, passes it on to pgroup_find_by_upgid's integer and
  stores it into the group table's upgid, none of which widens it, and
  the callers push integers: integer; and clears the status at entry:
  `out'.  The other tree's names (new_upgid: the body's `with' over the
  group's slot would hide `upgid', its field). }
{ body: proc2/pgroup_set_internal.pas }
procedure pgroup_set_internal(var entry: proc2_info_t;
                              new_upgid: integer;
                              out status_ret: status_$t);
  forward; internal;

{ pgroup_cleanup_internal, called before its body by
  proc2_$wait_reap_child: the entry by address and a word by value
  after the pad; the body writes the entry: `var'.  The other tree's
  names. }
{ body: proc2/pgroup_cleanup_internal.pas }
procedure pgroup_cleanup_internal(var entry: proc2_info_t;
                                         mode: integer);
  forward; internal;

{ pgroup_find_by_upgid, called before its body by PROC2_$WAIT: one word
  slot by value after the pad; the result a word.  The parameter is an
  integer: the body widens it signed against the table's pinteger upgid
  widened unsigned, and every caller pushes an integer.  Named
  wanted_upgid: the body's `with' over the group's slot would hide
  `upgid', its field.  The other tree's names otherwise. }
{ body: proc2/pgroup_find_by_upgid.pas }
function pgroup_find_by_upgid(wanted_upgid: integer): integer;
  forward; internal;

{ proc2_$build_info_internal, called before its body by PROC2_$INFO and
  PROC2_$GET_INFO: two word slots by value, then the block's and the
  status's addresses (no pad: the two words fill a longword).  Both
  addresses are `out': the block is written field by field and read
  only where it has been written; the status is cleared first and read
  only after PROC1_$GET_INFO and ACL_$GET_PID_SID store it.  The block
  is univ proc2_combined_info_t (above), so the callers' character
  arrays pass.  The pid's slot is passed on by address, a value
  parameter's own slot under internal.  The pid word is pinteger: scaled
  unsigned and compared with the pinteger PROC1_$CURRENT as words.  The
  other tree's names. }
{ body: proc2/build_info_internal.pas }
procedure proc2_$build_info_internal(proc2_index: integer;
                                     proc1_pid: pinteger;
                                     out info: univ proc2_combined_info_t;
                                     out status_ret: status_$t);
  forward; internal;

{ proc2_$entry_pgroup_upgid and proc2_$entry_pgroup_uid, called before
  their bodies by proc2_$build_info_internal: two addresses each, the
  entry's and the result's; the bodies read the entry's group index
  only and write the result only: the entry `in', the result `out'.
  The other tree's names (static helpers of its build_info_internal,
  which the image places among the group routines). }
{ body: proc2/entry_pgroup_upgid.pas }
procedure proc2_$entry_pgroup_upgid(in entry: proc2_info_t;
                                    out upgid_ret: pinteger);
  forward; internal;
{ body: proc2/entry_pgroup_uid.pas }
procedure proc2_$entry_pgroup_uid(in entry: proc2_info_t;
                                  out uid_ret: univ proc2_pgroup_uid_view_t);
  forward; internal;

{ proc2_$uid_to_upgid_internal, called before its body by
  PROC2_$PGUID_TO_UPGID: one slot, the UID's address (a record by
  address under internal), only read: `in', univ (the caller's uid_$t
  read through proc2_pgroup_uid_view_t's byte and word views); the
  result a word.  The other tree's names (a static helper of its
  pguid_to_upgid). }
{ body: proc2/uid_to_upgid_internal.pas }
function proc2_$uid_to_upgid_internal(
           in uid: univ proc2_pgroup_uid_view_t): pinteger;
  forward; internal;

{ proc2_$upgid_to_uid_internal, called before its body by
  PROC2_$UPGID_TO_UID: a word by value and the address of an 8-byte
  frame temporary, pushed with no pad, the caller copying the temporary
  out after the call; the body stores 8 bytes through the address: a
  function returning uid_$t through a hidden result address (a function
  returning a record through a hidden address is not padded; a
  procedure's word + address list is padded, as
  pgroup_cleanup_internal's call is).  The other tree's names (a static
  helper of its upgid_to_uid; its uid_ret is the result). }
{ body: proc2/upgid_to_uid_internal.pas }
function proc2_$upgid_to_uid_internal(upgid: integer): uid_$t;
  forward; internal;

{ proc2_$init_entry_internal (PROC2_CREATE_PRO; no map symbol), called
  before its body by PROC2_$CREATE and PROC2_$FORK, both from its own
  section: the entry by address, written: `var'.  The other tree's
  names. }
{ body: proc2/init_entry_internal.pas }
procedure proc2_$init_entry_internal(var entry: proc2_info_t);
  forward; internal;

{ proc2_$delete_cleanup (module-local, no map symbol;
  PROC2_DELETE_PRO), called before its body by PROC2_$DELETE, its one
  caller: no parameter slot read.  The other tree's name. }
{ body: proc2/delete_cleanup.pas }
procedure proc2_$delete_cleanup;
  forward; internal;

{ ---- OS_INIT_PROC ---- }
%include 'proc2/init.pas';                     { PROC2_$INIT }

{ ---- .TEXT ---- }
%include 'proc2/log_signal_event.pas';          { proc2_$log_signal_event }
%include 'proc2/cleanup_handlers_internal.pas';
  { proc2_$cleanup_handlers_internal }
%include 'proc2/awaken_guardian.pas';           { PROC2_$AWAKEN_GUARDIAN }
%include 'proc2/set_name.pas';                  { PROC2_$SET_NAME }
%include 'proc2/name_to_uid.pas';               { PROC2_$NAME_TO_UID }
%include 'proc2/deliver_signal_internal.pas';
  { proc2_$deliver_signal_internal }
%include 'proc2/deliver_pending_internal.pas';
  { proc2_$deliver_pending_internal }
%include 'proc2/deliver_fim.pas';               { PROC2_$DELIVER_FIM }
%include 'proc2/get_next_pending_signal.pas';
  { proc2_$get_next_pending_signal }
%include 'proc2/signal.pas';                    { PROC2_$SIGNAL }
%include 'proc2/signal_os.pas';                 { PROC2_$SIGNAL_OS }
%include 'proc2/quit.pas';                      { PROC2_$QUIT }
%include 'proc2/signal_pgroup_internal.pas';
  { proc2_$signal_pgroup_internal }
%include 'proc2/signal_pgroup.pas';             { PROC2_$SIGNAL_PGROUP }
%include 'proc2/signal_pgroup_os.pas';          { PROC2_$SIGNAL_PGROUP_OS }
%include 'proc2/acknowledge.pas';               { PROC2_$ACKNOWLEDGE }
%include 'proc2/deliver_pending.pas';           { PROC2_$DELIVER_PENDING }
%include 'proc2/sigreturn.pas';                 { PROC2_$SIGRETURN }
%include 'proc2/sigblock.pas';                  { PROC2_$SIGBLOCK }
%include 'proc2/sigsetmask.pas';                { PROC2_$SIGSETMASK }
%include 'proc2/get_sig_mask.pas';              { PROC2_$GET_SIG_MASK }
%include 'proc2/set_sig_mask.pas';              { PROC2_$SET_SIG_MASK }
%include 'proc2/sigpause.pas';                 { PROC2_$SIGPAUSE }
%include 'proc2/wait_reap_child.pas';          { proc2_$wait_reap_child }
%include 'proc2/wait_try_live_child.pas';      { proc2_$wait_try_live_child }
%include 'proc2/wait_try_zombie.pas';          { proc2_$wait_try_zombie }
%include 'proc2/wait.pas';                     { PROC2_$WAIT }
%include 'proc2/get_ec.pas';                   { PROC2_$GET_EC }
%include 'proc2/get_cr_rec.pas';               { PROC2_$GET_CR_REC }
%include 'proc2/list_pgroup.pas';              { PROC2_$LIST_PGROUP }
%include 'proc2/list.pas';                     { PROC2_$LIST }
%include 'proc2/list2.pas';                    { PROC2_$LIST2 }
%include 'proc2/zombie_list.pas';              { PROC2_$ZOMBIE_LIST }
%include 'proc2/find_index.pas';               { PROC2_$FIND_INDEX }
%include 'proc2/get_asid.pas';                 { PROC2_$GET_ASID }
%include 'proc2/find_asid.pas';                { PROC2_$FIND_ASID }
%include 'proc2/info.pas';                     { PROC2_$INFO }
%include 'proc2/get_info.pas';                 { PROC2_$GET_INFO }
%include 'proc2/build_info_internal.pas';      { proc2_$build_info_internal }
%include 'proc2/my_pid.pas';                   { PROC2_$MY_PID }
%include 'proc2/get_pid.pas';                  { PROC2_$GET_PID }
%include 'proc2/make_orphan.pas';              { PROC2_$MAKE_ORPHAN }
%include 'proc2/detach_from_parent.pas';       { proc2_$detach_from_parent }
%include 'proc2/upid_to_uid.pas';              { PROC2_$UPID_TO_UID }
%include 'proc2/uid_to_upid.pas';              { PROC2_$UID_TO_UPID }
%include 'proc2/upgid_to_uid.pas';             { PROC2_$UPGID_TO_UID }
%include 'proc2/pguid_to_upgid.pas';           { PROC2_$PGUID_TO_UPGID }
%include 'proc2/set_pgroup.pas';               { PROC2_$SET_PGROUP }
%include 'proc2/suspend.pas';                  { PROC2_$SUSPEND (its nested
                                                 proc2_$suspend_try first) }
%include 'proc2/resume.pas';                   { PROC2_$RESUME }
%include 'proc2/set_server.pas';               { PROC2_$SET_SERVER }
%include 'proc2/set_stack_trunc_size.pas';     { PROC2_$SET_STACK_TRUNC_SIZE }
%include 'proc2/set_priority.pas';             { PROC2_$SET_PRIORITY }
%include 'proc2/set_cleanup.pas';              { PROC2_$SET_CLEANUP }
%include 'proc2/shutdown.pas';                 { PROC2_$SHUTDOWN }
%include 'proc2/debug.pas';                    { PROC2_$DEBUG }
%include 'proc2/override_debug.pas';           { PROC2_$OVERRIDE_DEBUG }
%include 'proc2/undebug.pas';                  { PROC2_$UNDEBUG }
%include 'proc2/debug_unlink_from_list.pas';   { debug_unlink_from_list }
%include 'proc2/debug_setup_internal.pas';     { debug_setup_internal }
%include 'proc2/debug_clear_internal.pas';     { debug_clear_internal }
%include 'proc2/set_acct_info.pas';            { PROC2_$SET_ACCT_INFO }
%include 'proc2/get_boot_flags.pas';           { PROC2_$GET_BOOT_FLAGS }
%include 'proc2/get_debugger_pid.pas';         { PROC2_$GET_DEBUGGER_PID }
%include 'proc2/get_tty_data.pas';             { PROC2_$GET_TTY_DATA }
%include 'proc2/set_tty.pas';                  { PROC2_$SET_TTY }
%include 'proc2/set_session_id.pas';           { PROC2_$SET_SESSION_ID }
%include 'proc2/get_cpu_usage.pas';            { PROC2_$GET_CPU_USAGE }
%include 'proc2/align_ctl.pas';                { PROC2_$ALIGN_CTL }
%include 'proc2/get_regs.pas';                 { PROC2_$GET_REGS }
%include 'proc2/pgroup_info.pas';              { PROC2_$PGROUP_INFO }
%include 'proc2/pgroup_set_internal.pas';      { pgroup_set_internal }
%include 'proc2/pgroup_cleanup_internal.pas';  { pgroup_cleanup_internal (its
                                                 nested
                                                 pgroup_decr_leader_count
                                                 first) }
%include 'proc2/pgroup_inherit_internal.pas';
  { proc2_$pgroup_inherit_internal }
%include 'proc2/entry_pgroup_upgid.pas';       { proc2_$entry_pgroup_upgid }
%include 'proc2/entry_pgroup_uid.pas';         { proc2_$entry_pgroup_uid }
%include 'proc2/pgroup_find_by_upgid.pas';     { pgroup_find_by_upgid }
%include 'proc2/uid_to_pgroup_index.pas';      { proc2_$uid_to_pgroup_index }
%include 'proc2/uid_to_upgid_internal.pas';    { proc2_$uid_to_upgid_internal }
%include 'proc2/upgid_to_uid_internal.pas';    { proc2_$upgid_to_uid_internal }

{ ---- PROC2_CREATE_PRO ---- }
%include 'proc2/create.pas';                   { PROC2_$CREATE }
%include 'proc2/fork.pas';                     { PROC2_$FORK }
%include 'proc2/init_entry_internal.pas';      { proc2_$init_entry_internal }
%include 'proc2/startup.pas';                  { PROC2_$STARTUP }
%include 'proc2/set_valid.pas';                { PROC2_$SET_VALID }
%include 'proc2/complete_fork.pas';            { PROC2_$COMPLETE_FORK }
%include 'proc2/complete_vfork.pas';           { PROC2_$COMPLETE_VFORK }
%include 'proc2/who_am_i.pas';                 { PROC2_$WHO_AM_I }
%include 'proc2/get_upids.pas';                { PROC2_$GET_UPIDS }
%include 'proc2/get_my_upids.pas';             { PROC2_$GET_MY_UPIDS }

{ ---- PROC2_DELETE_PRO ---- }
%include 'proc2/delete.pas';                   { PROC2_$DELETE }
%include 'proc2/delete_cleanup.pas';           { proc2_$delete_cleanup }
