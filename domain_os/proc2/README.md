# The PROC2 subsystem in Domain Pascal

The level-2 process manager (the process table, process groups, signals,
waiting, debugging, process creation, fork and deletion).

## Layout

One module file, `proc2.pas`, `module proc2;` (the map segments'
name): one compilation unit in four code sections and four data
sections, the same four as ACL_'s (`../acl/README.md`).  The
.TEXT routines load A5 with the .DATA block, and PROC2_$INIT, in
OS_INIT_PROC, reaches the same block by its address: one unit, as ACL_.
The heading names no section (the block's objects are module variables,
two of them map symbols, and the bulk of the code is in .TEXT); the
routines of the other sections carry the attribute below (the rule's
form).

| section | code | routines (image order) | attribute |
|---------|------|------------------------|-----------|
| OS_INIT_PROC | PROC2, 0x578 bytes | PROC2_$INIT | `[section(os_init_proc, os_init_data)]` |
| .TEXT | PROC2, 0x3C10 bytes | 57 globals, PROC2_$AWAKEN_GUARDIAN .. PROC2_$PGROUP_INFO, with 25 module-local routines among and after them | none (the defaults) |
| PROC2_CREATE_PRO | PROC2, 0x130C bytes | PROC2_$CREATE .. PROC2_$GET_MY_UPIDS (9 globals) and the module-local proc2_$init_entry_internal | `[section(proc2_create_pro, proc2_create_dat)]` |
| PROC2_DELETE_PRO | PROC2, 0x6DC bytes | PROC2_$DELETE and the module-local proc2_$delete_cleanup | `[section(proc2_delete_pro, proc2_delete_dat)]` |

Data:

| block | section | contents |
|-------|---------|----------|
| PROC2, 0x1E8 bytes | .DATA | the module's variables (below) |
| PROC2, 4 bytes | OS_INIT_DATA | zero; A5 = its end in PROC2_$INIT, which does not use it |
| PROC2, 4 bytes | PROC2_CREATE_DAT | zero; A5 = its end in PROC2_$WHO_AM_I, PROC2_$GET_UPIDS and PROC2_$GET_MY_UPIDS, unused; the others of the section load no A5 |
| PROC2, 4 bytes | PROC2_DELETE_DAT | zero; A5 = its start (the end of FILE_'s block before it) in PROC2_$DELETE, the one exception to "A5 = the block's end" in these sections; proc2_$delete_cleanup loads no A5 |
| PROC2_$DATA, 0x4168 bytes | its own load section | the overlay `var (proc2_$data)` in `proc2_data.ins.pas` (below) |
| PROC2_WIRED_ASM, 0x690 bytes | WIRED_DATA | PROC2_$EC, the eventcount pairs: hand-written data (below) |

The three 4-byte blocks are the ACL_ shape (A5 at the end of a 4-byte
zero block); `proc2.pas` declares nothing for them (its TODO(pascal), as
`acl.pas`'s).

The .DATA block (zero in the image but the word 16#41 at +0x1E6; the
offsets are dpc's layout of the module):

| offset | variable | type |
|--------|----------|------|
| +0x000 | `proc2_$proc_dir_uid` | uid_$t |
| +0x008 | `proc2_$system_uid` | uid_$t |
| +0x010 | PROC2_$UID (`define`d, map symbol; extern in `proc2.ins.pas`) | array[0..57] of uid_$t |
| +0x1E0 | P2_INFO_ALLOC_PTR (`define`d, map symbol; extern in `proc2.ins.pas`) | integer |
| +0x1E2 | `proc2_$free_list_head` | integer |
| +0x1E4 | `proc2_$boot_flags` | proc2_boot_flags_t (a word with two packed booleans) |
| +0x1E6 | `proc2_$next_upid` | integer, 16#41 |

The names but the map's are the other tree's, prefixed `proc2_$`.

The overlay PROC2_$DATA (zero: loaded past the file's end), declared in
`proc2_data.ins.pas` (XPD includes it too; dpc gives every offset):

| offset | variable | type |
|--------|----------|------|
| +0x0000 | `proc2_$info_table` | array[1..70] of proc2_info_t (0xE4 each) |
| +0x3E58 | `proc2_unused_3e58` | 0x5E bytes no routine reaches |
| +0x3EB6 | `proc2_$pid_to_index` | array[0..64] of pinteger |
| +0x3F38 | `proc2_$pgroup_table` | array[1..70] of proc2_pgroup_entry_t (8 each), to +0x4168 |

The process-group table is indexed from 1, so an element 0 would
overlay the PID table's last four words; no routine uses it as a group.

PROC2_WIRED_ASM is hand-written data (the segment name ends in `_ASM`;
zero in the image), as EC2_ASM is: no module file; PROC2_$EC is declared
extern in `proc2_data.ins.pas`.

No fragment of another subsystem lies in PROC2's code segments (the
map's symbols there are all PROC2_ routines).

Routines: 95, the 68 globals of the map (1 + 57 + 9 + 1) and 27
module-local ones (no map symbol, `internal`, the other tree's names in
lower case).  None is hand assembly (there is no `proc2/sau2/`).  Two
are nested (called only by their parent with a bare `bsr`, each reads
its static link): proc2_$suspend_try in PROC2_$SUSPEND, a function of no
parameters that reaches the parent's status, index and suspend_result,
and pgroup_decr_leader_count in pgroup_cleanup_internal, which uses the
parent's status local.  Each is written inside its parent's fragment,
before it as in the image.  PROC2_$SET_STACK_TRUNC_SIZE is a compiled
empty procedure.

Forward headings in `proc2.pas` (each with its `body:` line) for the
module-local routines called before their bodies:
proc2_$deliver_signal_internal, proc2_$deliver_pending_internal,
proc2_$get_next_pending_signal, proc2_$uid_to_pgroup_index,
proc2_$detach_from_parent, debug_setup_internal, debug_clear_internal,
pgroup_set_internal, pgroup_cleanup_internal, pgroup_find_by_upgid,
proc2_$build_info_internal, proc2_$entry_pgroup_upgid,
proc2_$entry_pgroup_uid, proc2_$uid_to_upgid_internal,
proc2_$upgid_to_uid_internal (a function returning uid_$t through a
hidden address), proc2_$init_entry_internal and proc2_$delete_cleanup.
proc2_$pgroup_inherit_internal is called only from PROC2_CREATE_PRO,
after its body: no forward heading.

Module-level, not nested (each has its own frame and reads no static
link): the three wait helpers before PROC2_$WAIT, and
proc2_$delete_cleanup after PROC2_$DELETE (in the same fragment).

Routines whose image places are apart from the routine that uses them
have fragments of their own, included at their places:
proc2_$get_next_pending_signal (PROC2_$DELIVER_FIM lies between it and
proc2_$deliver_pending_internal); proc2_$entry_pgroup_upgid and
proc2_$entry_pgroup_uid (proc2_$build_info_internal's helpers, among the
group routines); proc2_$uid_to_upgid_internal and
proc2_$upgid_to_uid_internal (the two UNIX id routines' helpers, at the
end of .TEXT).

## Routines and their fragments

| routine | section | fragment |
|---------|---------|----------|
| PROC2_$INIT | OS_INIT_PROC | `init.pas` |
| proc2_$log_signal_event | .TEXT | `log_signal_event.pas` |
| proc2_$cleanup_handlers_internal | .TEXT | `cleanup_handlers_internal.pas` |
| PROC2_$AWAKEN_GUARDIAN | .TEXT | `awaken_guardian.pas` |
| PROC2_$SET_NAME | .TEXT | `set_name.pas` |
| PROC2_$NAME_TO_UID | .TEXT | `name_to_uid.pas` |
| proc2_$deliver_signal_internal | .TEXT | `deliver_signal_internal.pas` |
| proc2_$deliver_pending_internal | .TEXT | `deliver_pending_internal.pas` |
| PROC2_$DELIVER_FIM | .TEXT | `deliver_fim.pas` |
| proc2_$get_next_pending_signal | .TEXT | `get_next_pending_signal.pas` |
| PROC2_$SIGNAL | .TEXT | `signal.pas` |
| PROC2_$SIGNAL_OS | .TEXT | `signal_os.pas` |
| PROC2_$QUIT | .TEXT | `quit.pas` |
| proc2_$signal_pgroup_internal | .TEXT | `signal_pgroup_internal.pas` |
| PROC2_$SIGNAL_PGROUP | .TEXT | `signal_pgroup.pas` |
| PROC2_$SIGNAL_PGROUP_OS | .TEXT | `signal_pgroup_os.pas` |
| PROC2_$ACKNOWLEDGE | .TEXT | `acknowledge.pas` |
| PROC2_$DELIVER_PENDING | .TEXT | `deliver_pending.pas` |
| PROC2_$SIGRETURN | .TEXT | `sigreturn.pas` |
| PROC2_$SIGBLOCK | .TEXT | `sigblock.pas` |
| PROC2_$SIGSETMASK | .TEXT | `sigsetmask.pas` |
| PROC2_$GET_SIG_MASK | .TEXT | `get_sig_mask.pas` |
| PROC2_$SET_SIG_MASK | .TEXT | `set_sig_mask.pas` |
| PROC2_$SIGPAUSE | .TEXT | `sigpause.pas` |
| proc2_$wait_reap_child | .TEXT | `wait_reap_child.pas` |
| proc2_$wait_try_live_child | .TEXT | `wait_try_live_child.pas` |
| proc2_$wait_try_zombie | .TEXT | `wait_try_zombie.pas` |
| PROC2_$WAIT | .TEXT | `wait.pas` |
| PROC2_$GET_EC | .TEXT | `get_ec.pas` |
| PROC2_$GET_CR_REC | .TEXT | `get_cr_rec.pas` |
| PROC2_$LIST_PGROUP | .TEXT | `list_pgroup.pas` |
| PROC2_$LIST | .TEXT | `list.pas` |
| PROC2_$LIST2 | .TEXT | `list2.pas` |
| PROC2_$ZOMBIE_LIST | .TEXT | `zombie_list.pas` |
| PROC2_$FIND_INDEX | .TEXT | `find_index.pas` |
| PROC2_$GET_ASID | .TEXT | `get_asid.pas` |
| PROC2_$FIND_ASID | .TEXT | `find_asid.pas` |
| PROC2_$INFO | .TEXT | `info.pas` |
| PROC2_$GET_INFO | .TEXT | `get_info.pas` |
| proc2_$build_info_internal | .TEXT | `build_info_internal.pas` |
| PROC2_$MY_PID | .TEXT | `my_pid.pas` |
| PROC2_$GET_PID | .TEXT | `get_pid.pas` |
| PROC2_$MAKE_ORPHAN | .TEXT | `make_orphan.pas` |
| proc2_$detach_from_parent | .TEXT | `detach_from_parent.pas` |
| PROC2_$UPID_TO_UID | .TEXT | `upid_to_uid.pas` |
| PROC2_$UID_TO_UPID | .TEXT | `uid_to_upid.pas` |
| PROC2_$UPGID_TO_UID | .TEXT | `upgid_to_uid.pas` |
| PROC2_$PGUID_TO_UPGID | .TEXT | `pguid_to_upgid.pas` |
| PROC2_$SET_PGROUP | .TEXT | `set_pgroup.pas` |
| proc2_$suspend_try | .TEXT | `suspend.pas` (nested) |
| PROC2_$SUSPEND | .TEXT | `suspend.pas` |
| PROC2_$RESUME | .TEXT | `resume.pas` |
| PROC2_$SET_SERVER | .TEXT | `set_server.pas` |
| PROC2_$SET_STACK_TRUNC_SIZE | .TEXT | `set_stack_trunc_size.pas` |
| PROC2_$SET_PRIORITY | .TEXT | `set_priority.pas` |
| PROC2_$SET_CLEANUP | .TEXT | `set_cleanup.pas` |
| PROC2_$SHUTDOWN | .TEXT | `shutdown.pas` |
| PROC2_$DEBUG | .TEXT | `debug.pas` |
| PROC2_$OVERRIDE_DEBUG | .TEXT | `override_debug.pas` |
| PROC2_$UNDEBUG | .TEXT | `undebug.pas` |
| debug_unlink_from_list | .TEXT | `debug_unlink_from_list.pas` |
| debug_setup_internal | .TEXT | `debug_setup_internal.pas` |
| debug_clear_internal | .TEXT | `debug_clear_internal.pas` |
| PROC2_$SET_ACCT_INFO | .TEXT | `set_acct_info.pas` |
| PROC2_$GET_BOOT_FLAGS | .TEXT | `get_boot_flags.pas` |
| PROC2_$GET_DEBUGGER_PID | .TEXT | `get_debugger_pid.pas` |
| PROC2_$GET_TTY_DATA | .TEXT | `get_tty_data.pas` |
| PROC2_$SET_TTY | .TEXT | `set_tty.pas` |
| PROC2_$SET_SESSION_ID | .TEXT | `set_session_id.pas` |
| PROC2_$GET_CPU_USAGE | .TEXT | `get_cpu_usage.pas` |
| PROC2_$ALIGN_CTL | .TEXT | `align_ctl.pas` |
| PROC2_$GET_REGS | .TEXT | `get_regs.pas` |
| PROC2_$PGROUP_INFO | .TEXT | `pgroup_info.pas` |
| pgroup_set_internal | .TEXT | `pgroup_set_internal.pas` |
| pgroup_decr_leader_count | .TEXT | `pgroup_cleanup_internal.pas` (nested) |
| pgroup_cleanup_internal | .TEXT | `pgroup_cleanup_internal.pas` |
| proc2_$pgroup_inherit_internal | .TEXT | `pgroup_inherit_internal.pas` |
| proc2_$entry_pgroup_upgid | .TEXT | `entry_pgroup_upgid.pas` |
| proc2_$entry_pgroup_uid | .TEXT | `entry_pgroup_uid.pas` |
| pgroup_find_by_upgid | .TEXT | `pgroup_find_by_upgid.pas` |
| proc2_$uid_to_pgroup_index | .TEXT | `uid_to_pgroup_index.pas` |
| proc2_$uid_to_upgid_internal | .TEXT | `uid_to_upgid_internal.pas` |
| proc2_$upgid_to_uid_internal | .TEXT | `upgid_to_uid_internal.pas` |
| PROC2_$CREATE | PROC2_CREATE_PRO | `create.pas` |
| PROC2_$FORK | PROC2_CREATE_PRO | `fork.pas` |
| proc2_$init_entry_internal | PROC2_CREATE_PRO | `init_entry_internal.pas` |
| PROC2_$STARTUP | PROC2_CREATE_PRO | `startup.pas` |
| PROC2_$SET_VALID | PROC2_CREATE_PRO | `set_valid.pas` |
| PROC2_$COMPLETE_FORK | PROC2_CREATE_PRO | `complete_fork.pas` |
| PROC2_$COMPLETE_VFORK | PROC2_CREATE_PRO | `complete_vfork.pas` |
| PROC2_$WHO_AM_I | PROC2_CREATE_PRO | `who_am_i.pas` |
| PROC2_$GET_UPIDS | PROC2_CREATE_PRO | `get_upids.pas` |
| PROC2_$GET_MY_UPIDS | PROC2_CREATE_PRO | `get_my_upids.pas` |
| PROC2_$DELETE | PROC2_DELETE_PRO | `delete.pas` |
| proc2_$delete_cleanup | PROC2_DELETE_PRO | `delete_cleanup.pas` |

Headings (`proc2.ins.pas`): every PROC2_ global the default convention
(every argument by address) but PROC2_$SET_CLEANUP (one word by value)
and PROC2_$DELIVER_FIM (`val_param`, two addresses by value); the
module-local routines take words by value and records by address
(`internal`).  Value parameters copied at entry (the UID of many
lookups) are value parameters; a UID only read through its slot is
`in`.  Where a body's `with` over an entry would hide a parameter of a
field's name, the parameter has another name (proc_name, upid_ret,
new_upgid, wanted_upgid, new_tty_uid, new_session).

## Insert files

- `proc2.ins.pas` (shared; other subsystems' headings come first):
  PROC2's statuses (the SR10.2 status-code database's texts; Apollo's
  names for 16#00190001..16#00190004, the other tree's otherwise), the
  cleanup handler bits `proc2_$cleanup_lpr` .. `_xns_idp` (new names,
  after the routine each bit selects), the signal numbers (Apollo's) and
  signal sets (new names), the fault status `proc2_$fault_param_t`, the
  process name, the signal-mask records, the wait records
  (`proc2_$wait_data_t`, `proc2_$wait_usage_t` with its nested
  `proc2_$usage_counts_t`, `proc2_$exit_t`, `proc2_$wait_result_t`), the
  startup context's two records, PROC2_$UID and P2_INFO_ALLOC_PTR
  (extern), and every global's heading.
- `proc2_data.ins.pas` (XPD's too): the process entry `proc2_info_t`
  (its flags word a variant of a set and sixteen booleans, its two
  blocked sets one record, a live arm and a zombie arm from +0x60), the
  ptrace options, the cleanup set, the accounting id, the zombie's
  flags word, the process-group entry, the eventcount pair, the flags
  members as constants, PROC2_$EC (extern) and the overlay section
  PROC2_$DATA.
- `proc2.pas` itself: the audit record, the PROC1_$STATS view, the
  information block `proc2_combined_info_t`, the group UID's views, the
  creation record `proc2_cr_rec_t`, the boot shell's header, the boot
  stack and the boot flags' word, the directory entry
  `proc2_dirent_t`; PROC1_$SUSPEND_EC (extern, as `../proc1/proc1.pas`
  declares it) and a copy of DIR_$DIR_READU's heading.
- `../lpr/lpr.ins.pas`: LPR_$RELEASE's heading (hand assembly), its
  first parameter `in boolean` (PROC2_$GET_ASID's `false` cell is shared
  with proc2_$cleanup_handlers_internal's).
- `../fim/fim.ins.pas`: `fim_$sigcontext_t`, FIM_$FAULT_RETURN,
  FIM_$INITIAL_STACK_SIZE, FIM_$FP_INIT and FIM_$PROC2_STARTUP (its
  argument `univ`).
- Used as they are: base, misc (CRASH_SYSTEM), ec, ml, time, uid, mmu,
  mst, proc1, acl, audit, os, peb, xpd, lpr, mt, ct, disk, pbu, pkt,
  netbuf, sock, net_io, route, rip, msg, gpu, pchist, scsi, mac_os, xns,
  xns_idp, as, dtty, tape, flop, name, file, cal, smd, dma, suma, term,
  pacct, rem_name, dir.

The SAU9's PROC2 (and the other 68020 builds', SAU6..SAU8) is this
source with no conditional arm: PROC2_$INIT, _$CREATE, _$FORK,
_$GET_MY_UPIDS, _$DELETE, _$QUIT, _$GET_SIG_MASK, _$WAIT, _$FIND_ASID
and _$MAKE_ORPHAN, whose code generation differs, have their sau9
addresses.

## Open items

Facts of the image's form:
- Apollo's signal numbers, not 4.3BSD's: PROC2_$AWAKEN_GUARDIAN sends
  SIGCLD (18) and SIGCHLD (23); the signals compared in delivery are
  SIGKILL, SIGAPOLLO, SIGCONT and SIGHUP; PROC2_$ACKNOWLEDGE's members
  19 and 21 are SIGSTOP and SIGCONT.
- PBU_$FREE_ASID and SCSI_$FREE_ASID are bare `rts` routines; the
  cleanup routine pushes an argument for them, and the Pascal passes it.
- PROC2_$DELIVER_FIM's third parameter is FIM_$BUILD_DF's user stack
  pointer, replaced with the entry's longword at +0x8C for a signal
  taken on the signal stack.
- proc2_$signal_pgroup_internal passes ACL_$CHECK_FAULT_RIGHTS the
  address of PROC1_$CURRENT where PROC2_$SIGNAL passes the sender's
  entry's level-1 PID.
- PROC2_$GET_SIG_MASK copies the two blocked sets as one 8-byte record;
  PROC2_$SET_SIG_MASK copies 16#20 bytes of each record in.
- PROC2_$WAIT clears its local result's flag_64 at entry as well as the
  caller's; proc2_$wait_try_zombie's options parameter is never read.
- PROC2_$GET_CR_REC stores proc2_$uid_not_found also when
  EC2_$GET_EC1_ADDR fails (its own status is not returned).
- PROC2_$ZOMBIE_LIST is PROC2_$LIST2 with the zombie member for member 7.
- PROC2_$INFO's and PROC2_$GET_INFO's frames hold an unaddressed
  16#E4-byte block besides their local block: both originals declare a
  second local of the block's size that they never use (the stand-in
  `unused_1d0`).
- proc2_$detach_from_parent marks the live child with bit 15 (the init
  member), not the orphan member.
- pgroup_decr_leader_count's second signal, 22, is Apollo's SIGCONT; its
  flag test is member 6, proc2_pf_stopped.
- PROC2_$DELETE's proc2_$delete_cleanup is module-level, not nested.
  Flags member 3 (proc2_pf_debug) is what PACCT_$LOG takes as its fork
  flag, PROC2_$FORK sets and PROC2_$CREATE and PROC2_$SET_ACCT_INFO
  clear: 4.3BSD's AFORK (a lead for the name).
- The fragments that store or compare the name length's two special
  values as `chr(16#21)` and `chr(16#22)` (init.pas,
  init_entry_internal.pas, set_name.pas, build_info_internal.pas) could
  use proc2_name_len_none and proc2_name_len_by_uid (not case labels, so
  not changed).
- The callers of PROC2_$SET_CLEANUP (NET_$OPEN, MSG_$OPEN,
  MSG_$ALLOCATE, PCHIST_$UNIX_PROFIL_CNTL, TIME_$SET_ITIMER) pass the
  handler bits as numbers; they could use the `proc2_$cleanup_*` names
  (not in PROC2's write set).
- DIR_$DIR_READU's heading has two copies, `../dir/dir.pas`'s own and
  `proc2.pas`'s: it has no home in `../dir/dir.ins.pas` because its
  continuation is rem_name's.

### TODO(pascal)

- `proc2.pas`: the three 4-byte data blocks (no object in any;
  PROC2_$DELETE's A5 is its block's start; why the compiler emits the
  blocks is open).
- `get_next_pending_signal.pas`: the empty-set path returns sig's
  register with no result store.
- Frames with unaddressed bytes and stand-ins: `shutdown.pas` (40
  bytes), `align_ctl.pas` (16), `get_regs.pas` (156),
  `pgroup_set_internal.pas` (beyond dpc's layout),
  `pgroup_cleanup_internal.pas` (the nested pgroup_decr_leader_count's
  4), `pgroup_inherit_internal.pas` (8), `pgroup_find_by_upgid.pas` (4),
  `init.pas` (its holes and the 8-byte difference), `set_valid.pas` (4),
  `complete_vfork.pas` (24), `delete_cleanup.pas` (proc2_$delete_cleanup's).

## Named dispatch codes

proc2_$cleanup_handlers_internal passes PCHIST_$UNIX_PROFIL_CNTL's
command as `pchist_$profil_disable` (`../pchist/pchist.ins.pas`).
