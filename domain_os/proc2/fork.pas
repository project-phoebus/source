{ PROC2_$FORK - fork the calling process.

  Image addresses:
    sau2  0x00E72BCE  PROC2_$FORK
    sau9  0x3C47A5BA  PROC2_$FORK

  - Under ml_$proc2_lock a free slot gets an ASID (a vfork child, flags
    0, runs in its parent's), a level-1 stack, a process bound at
    PROC2_$STARTUP and the parent's signal state, as the first child.
  - Unlocked: the ACL and audit state, and unless a vfork the file
    locks, MSG's, MST's, NAME's and PCHIST's forks; the child is resumed
    and the parent waits.
  - A failure after the ASID undoes it all.
  - The back links, the ALLOC_ASID failure's status and the fail-bit
    test are PROC2_$CREATE's.

  Status stored:
    the last step's status: the child was forked
    status_$proc2_table_full: no free slot
    the local status: no ASID
    the failed step's status, its fail bit set unless its code is 16#19:
      a later step failed
}

[section(proc2_create_pro, proc2_create_dat)]
procedure proc2_$fork(in entry_point: integer32;
                      in user_data: integer32;
                      in fork_flags: integer32;
                      out uid_ret: uid_$t;
                      in reserved: integer32;
                      out upid_ret: integer;
                      out ec_ret: univ_ptr;
                      out status_ret: status_$t);
label
  set_priority, cleanup_locked, cleanup_entry, done;
var
  unused_4: integer32;                    { nothing addressed }
  ec_list: ec_$waitn_ecs_t;
  unused_c: integer32;                    { nothing addressed }
  wait_val: ec_$waitn_vals_t;
  va_info: integer32;
  unused_1a: array[1..3] of integer;      { nothing addressed }
  creation_time: time_$clock_t;
  unused_24: integer32;                   { nothing addressed }
  temp_status: status_$t;
  status: status_$t;
  va_extra: mst_$va_extra_t;
  unused_3e: array[1..2] of integer;      { nothing addressed }
  max_priority: integer;
  min_priority: integer;
  va_modified: boolean;
  va_active: boolean;
  new_idx: integer;
  parent_idx: integer;
  file_locked: boolean;
  stack: linteger;
  registered_ec: univ_ptr;
  ctx: linteger;
  new_entry: proc2_info_ptr_t;
  parent_entry: proc2_info_ptr_t;
begin
  file_locked := false;
  parent_idx := proc2_$pid_to_index[proc1_$current];
  ml_$lock(ml_$proc2_lock);
  time_$clock(creation_time);
  new_idx := proc2_$free_list_head;
  if new_idx = 0 then begin
    status_ret.all := status_$proc2_table_full;
    ml_$unlock(ml_$proc2_lock);
    return;
  end;
  new_entry := addr(proc2_$info_table[new_idx]);
  parent_entry := addr(proc2_$info_table[parent_idx]);
  proc2_$free_list_head := new_entry^.next_index;
  new_entry^.next_index := p2_info_alloc_ptr;
  p2_info_alloc_ptr := new_idx;
  proc2_$info_table[new_entry^.next_index].pad_14 := new_idx;

  new_entry^.pad_14 := 0;
  new_entry^.parent_pgroup_idx := 0;
  new_entry^.flags.alt_asid := fork_flags = 0;
  new_entry^.flags.bits := new_entry^.flags.bits + [proc2_pf_orphan];

  new_entry^.flags.bits := new_entry^.flags.bits - [proc2_pf_init];

  new_entry^.cr_rec_2 := parent_entry^.cr_rec_2;
  new_entry^.cr_rec := user_data;
  new_entry^.asid := mst_$alloc_asid(status_ret);
  if status_ret.code <> 0 then begin
    status_ret.fail := true;
    goto cleanup_entry;
  end;
  if proc2_pf_alt_asid in new_entry^.flags.bits then begin
    new_entry^.asid_alt := new_entry^.asid;
    new_entry^.asid := parent_entry^.asid;
    new_entry^.stack_uid := parent_entry^.stack_uid;
  end
  else
    new_entry^.asid_alt := 0;
  proc2_$init_entry_internal(new_entry^);
  stack := proc1_$alloc_stack(16#1000, status);
  if status.code <> 0 then
    goto cleanup_locked;
  ctx := stack - (16 + fim_$initial_stack_size);
  with proc2_$startup_context_ptr_t(ctx)^ do begin
    args.usp := user_data;
    args.asid := new_entry^.asid;
    args.pc := entry_point;
    self_ptr := ctx + 4;
  end;
  new_entry^.level1_pid := proc1_$bind(addr(proc2_$startup), univ_ptr(ctx),
                                       stack, 0, status);
  if status.code <> 0 then
    goto cleanup_locked;
  new_entry^.flags.bits := new_entry^.flags.bits + [proc2_pf_bound];

  proc2_$pid_to_index[new_entry^.level1_pid] := new_idx;
  new_entry^.sig_pending := parent_entry^.sig_pending;
  new_entry^.sig_blocked.blocked_1 := parent_entry^.sig_blocked.blocked_1;

  new_entry^.sig_blocked.blocked_2 := parent_entry^.sig_blocked.blocked_2;

  new_entry^.sig_mask_3 := parent_entry^.sig_mask_3;
  new_entry^.sig_mask_1 := parent_entry^.sig_mask_1;
  new_entry^.sig_mask_4 := parent_entry^.sig_mask_4;
  new_entry^.flags.on_sig_stack :=
    proc2_pf_on_sig_stack in parent_entry^.flags.bits;
  new_entry^.flags.no_cld_stop :=
    proc2_pf_no_cld_stop in parent_entry^.flags.bits;
  new_entry^.pad_18[2] := parent_entry^.pad_18[1];
  new_entry^.pad_18[1] := new_entry^.pad_18[2];
  new_entry^.next_child_sibling := parent_entry^.first_child_idx;

  parent_entry^.first_child_idx := new_idx;
  new_entry^.parent_pgroup_idx := parent_idx;
  new_entry^.creation_time.high := creation_time.high;
  new_entry^.creation_time.low := creation_time.low;
  new_entry^.flags.bits := new_entry^.flags.bits + [proc2_pf_debug];

  new_entry^.acct_info := parent_entry^.acct_info;
  new_entry^.acct.info_len := parent_entry^.acct.info_len;
  new_entry^.acct.uid := parent_entry^.acct.uid;
  new_entry^.tty_uid := parent_entry^.tty_uid;
  with proc2_$ec[new_entry^.self_index] do begin
    ec_$init(fork_ec);
    fork_ec.value := -1;
    ec_$init(cr_rec_ec);
    registered_ec := ec2_$register_ec1(addr(fork_ec), status);

  end;
  if status.code <> 0 then
    goto cleanup_locked;
  ml_$unlock(ml_$proc2_lock);
  uid_ret := new_entry^.uid;
  upid_ret := new_entry^.upid;
  ec_ret := registered_ec;
  acl_$alloc_asid(new_entry^.level1_pid, status);
  audit_$inherit_audit(new_entry^.level1_pid, status);
  fim_$user_fim_addr[new_entry^.asid] :=
    fim_$user_fim_addr[proc1_$as_id];
  if fim_$user_fim_addr[new_entry^.asid] <> 0 then
    fim_$quit_inh[new_entry^.asid] := false;
  if proc2_pf_alt_asid in new_entry^.flags.bits then
    goto set_priority;
  if proc1_$current <> 1 then begin
    file_$fork_lock(new_entry^.asid, status);
    if status.all <> status_$ok then
      goto cleanup_locked;
    file_locked := true;
  end;
  if proc2_$cleanup_msg in parent_entry^.cleanup_flags then
    if msg_$fork(proc1_$as_id, new_entry^.asid) then
      new_entry^.cleanup_flags :=
        new_entry^.cleanup_flags + [proc2_$cleanup_msg];
  mst_$fork(new_entry^.asid, new_entry^.level1_pid, fork_flags, status);

  if status.code <> 0 then
    goto cleanup_locked;
  mst_$get_va_info(new_entry^.asid, new_entry^.cr_rec_2,
                   new_entry^.parent_uid, va_info, va_extra, va_active,
                   va_modified, status);
  if status.code <> 0 then
    goto cleanup_locked;
  mst_$get_va_info(new_entry^.asid, new_entry^.cr_rec - 1,
                   new_entry^.stack_uid, va_info, va_extra, va_active,
                   va_modified, status);
  if status.code <> 0 then
    goto cleanup_locked;
  name_$fork(proc1_$as_id, new_entry^.asid);
  if proc2_$cleanup_pchist in parent_entry^.cleanup_flags then begin

    pchist_$unix_profil_fork(new_entry^.level1_pid, new_entry^.asid);

    new_entry^.cleanup_flags :=
      new_entry^.cleanup_flags + [proc2_$cleanup_pchist];
  end;
set_priority:
  if proc1_$current = 1 then begin
    max_priority := 14;
    min_priority := 3;
  end
  else
    proc1_$set_priority(proc1_$current, false, min_priority,
                        max_priority);
  if (parent_entry^.debugger_idx <> 0)
     and then xpd_$inherit_ptrace_options(parent_entry^.ptrace_opts)
     then begin
    ml_$lock(ml_$proc2_lock);
    debug_setup_internal(new_entry^.self_index, parent_entry^.debugger_idx,
                         false);
    new_entry^.ptrace_opts := parent_entry^.ptrace_opts;
    ml_$unlock(ml_$proc2_lock);
  end;
  proc1_$set_priority(new_entry^.level1_pid, true, min_priority,
                      max_priority);
  wait_val[1] := ec_$read(proc2_$ec[new_entry^.self_index].fork_ec) + 1;

  ec_list[1] := addr(proc2_$ec[new_entry^.self_index].fork_ec);

  proc1_$set_type(new_entry^.level1_pid, 2);
  proc1_$resume(new_entry^.level1_pid, status);
  if status.code <> 0 then
    crash_system(status);
  discard(ec_$waitn(ec_list, wait_val, 1));
  if not (xpd_pf_debug_target in new_entry^.flags.bits) then

    ec_ret := nil;
  goto done;
cleanup_locked:
  if not proc1_$tst_lock(ml_$proc2_lock) then
    ml_$lock(ml_$proc2_lock);
  if new_entry^.parent_pgroup_idx <> 0 then
    proc2_$info_table[new_entry^.parent_pgroup_idx].first_child_idx :=
      new_entry^.next_child_sibling;
  if proc2_pf_bound in new_entry^.flags.bits then
    proc1_$unbind(new_entry^.level1_pid, temp_status)
  else if stack <> 0 then
    proc1_$free_stack(stack);
  if status.code <> 16#19 then
    status.fail := true;
  if file_locked then
    file_$priv_unlock_all(new_entry^.asid);
  if proc2_pf_alt_asid in new_entry^.flags.bits then begin
    mst_$free_asid(new_entry^.asid_alt, temp_status);
    proc2_$uid[new_entry^.asid] := parent_entry^.uid;
  end
  else begin
    mst_$free_asid(new_entry^.asid, temp_status);
    proc2_$uid[new_entry^.asid] := proc2_$system_uid;
  end;
  if new_entry^.cleanup_flags <> [] then
    proc2_$cleanup_handlers_internal(new_entry^);
cleanup_entry:
  pgroup_cleanup_internal(new_entry^, 2);
  if new_entry^.pad_14 = 0 then
    p2_info_alloc_ptr := new_entry^.next_index
  else
    proc2_$info_table[new_entry^.pad_14].next_index :=
      new_entry^.next_index;
  proc2_$info_table[new_entry^.next_index].pad_14 := new_entry^.pad_14;

  new_entry^.next_index := proc2_$free_list_head;
  proc2_$free_list_head := new_idx;
  new_entry^.parent_uid := uid_$nil;
  new_entry^.flags.bits := new_entry^.flags.bits - [proc2_pf_bound];

  new_entry^.uid := proc2_$system_uid;
  ml_$unlock(ml_$proc2_lock);
done:
  status_ret := status;
end;
