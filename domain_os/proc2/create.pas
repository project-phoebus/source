{ PROC2_$CREATE - create a new process.

  Image addresses:
    sau2  0x00E726EC  PROC2_$CREATE
    sau9  0x3C47A0F0  PROC2_$CREATE

  - Under ml_$proc2_lock a free slot gets an ASID, its initial area, a
    level-1 stack and a process bound at PROC2_$STARTUP, linked under the
    caller; then, unlocked, the ACL, audit and naming state.
  - A failure after the ASID undoes it all.
  - Back links are written without a zero test; the ALLOC_ASID failure
    stores the local status; the fail-bit test compares the code word
    with 16#19.

  Status stored:
    the last step's status: the process was created
    status_$proc2_table_full: no free slot
    the local status: no ASID (MST_$ALLOC_ASID's status, fail bit set,
      is stored first)
    the failed step's status, its fail bit set unless its code is 16#19:
      a later step failed
}

[section(proc2_create_pro, proc2_create_dat)]
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
                        out status_ret: status_$t);
label
  cleanup_asid, cleanup_entry, done;
var
  parent: uid_$t;
  unused_a: integer;                      { nothing addressed }
  creation_time: time_$clock_t;
  temp_status: status_$t;
  status: status_$t;
  code: integer32;
  entry_pc: integer32;
  user_sp: integer32;
  stack: linteger;
  new_entry: proc2_info_ptr_t;
  cur_entry: proc2_info_ptr_t;
  new_idx: integer;
  init: boolean;
  map: integer32;
  ctx: linteger;
  unused_3e: integer;                     { nothing addressed }
  max_priority: integer;
  min_priority: integer;
  unused_5c: array[1..11] of integer;     { nothing addressed }
begin
  parent := parent_uid;
  code := code_desc;
  map := map_param;
  entry_pc := entry_point;
  user_sp := user_data;
  stack := 0;
  init := init_flag;
  ml_$lock(ml_$proc2_lock);
  time_$clock(creation_time);
  new_idx := proc2_$free_list_head;
  if new_idx = 0 then begin
    status_ret.all := status_$proc2_table_full;
    ml_$unlock(ml_$proc2_lock);
    return;
  end;
  new_entry := addr(proc2_$info_table[new_idx]);
  cur_entry := addr(proc2_$info_table[
                 proc2_$pid_to_index[proc1_$current]]);
  proc2_$free_list_head := new_entry^.next_index;
  new_entry^.next_index := p2_info_alloc_ptr;
  p2_info_alloc_ptr := new_idx;
  proc2_$info_table[new_entry^.next_index].pad_14 := new_idx;

  new_entry^.pad_14 := 0;
  new_entry^.parent_pgroup_idx := 0;
  new_entry^.asid := mst_$alloc_asid(status_ret);
  if status_ret.code <> 0 then begin
    status_ret.fail := true;
    goto cleanup_entry;
  end;
  fim_$fp_init(new_entry^.asid);
  new_entry^.flags.init := init;
  proc2_$init_entry_internal(new_entry^);
  new_entry^.parent_uid := parent;
  new_entry^.cr_rec_2 := code;
  new_entry^.cr_rec := user_sp;
  mst_$map_initial_area(code, new_entry^.asid, parent, map, 7, false,
                        status);
  if status.code <> 0 then
    goto cleanup_asid;
  new_entry^.stack_uid := uid_$nil;
  stack := proc1_$alloc_stack(16#1000, status);
  if status.code <> 0 then
    goto cleanup_asid;
  ctx := stack - (16 + fim_$initial_stack_size);
  with proc2_$startup_context_ptr_t(ctx)^ do begin
    args.usp := user_sp;
    args.asid := new_entry^.asid;
    args.pc := entry_pc;
    self_ptr := ctx + 4;
  end;
  new_entry^.level1_pid := proc1_$bind(addr(proc2_$startup), univ_ptr(ctx), stack,
                                       0, status);
  if status.code <> 0 then
    goto cleanup_asid;
  new_entry^.flags.bits := new_entry^.flags.bits + [proc2_pf_bound];

  proc2_$pid_to_index[new_entry^.level1_pid] := new_idx;
  new_entry^.sig_pending := [];
  new_entry^.sig_blocked.blocked_1 := [];
  new_entry^.sig_blocked.blocked_2 := [];
  new_entry^.sig_mask_3 := [];
  new_entry^.sig_mask_1 := [];
  new_entry^.flags.bits := new_entry^.flags.bits
                           - [proc2_pf_no_cld_stop, proc2_pf_on_sig_stack,
                              proc2_pf_alt_asid, proc2_pf_orphan];

  new_entry^.pad_18[1] := 0;
  new_entry^.pad_18[2] := cur_entry^.pad_18[1];
  new_entry^.flags.bits := new_entry^.flags.bits - [proc2_pf_debug];

  new_entry^.acct.uid := parent;
  new_entry^.acct.info_len := 0;
  new_entry^.creation_time.high := creation_time.high;
  new_entry^.creation_time.low := creation_time.low;
  new_entry^.tty_uid := cur_entry^.tty_uid;
  if init then begin
    new_entry^.parent_pgroup_idx := 0;
    new_entry^.next_child_sibling := 0;
  end
  else begin
    new_entry^.parent_pgroup_idx := cur_entry^.self_index;
    new_entry^.next_child_sibling := cur_entry^.first_child_idx;

    cur_entry^.first_child_idx := new_idx;
  end;
  if (cur_entry^.debugger_idx <> 0)
     and then xpd_$inherit_ptrace_options(cur_entry^.ptrace_opts) then begin

    debug_setup_internal(new_entry^.self_index, cur_entry^.debugger_idx,
                         false);
    new_entry^.ptrace_opts := cur_entry^.ptrace_opts;
  end;
  with proc2_$ec[new_entry^.self_index] do begin
    ec_$init(fork_ec);
    ec_$init(cr_rec_ec);
    ec_ret := ec2_$register_ec1(addr(fork_ec), status);
  end;
  if status.code <> 0 then
    goto cleanup_asid;
  ml_$unlock(ml_$proc2_lock);
  uid_ret := new_entry^.uid;
  acl_$alloc_asid(new_entry^.level1_pid, status);
  audit_$inherit_audit(new_entry^.level1_pid, status);
  name_$init_asid(new_entry^.asid, status);
  if status.code <> 0 then
    goto cleanup_asid;
  if proc1_$current = 1 then begin
    max_priority := 14;
    min_priority := 3;
  end
  else
    proc1_$set_priority(proc1_$current, false, min_priority,
                        max_priority);
  proc1_$set_priority(new_entry^.level1_pid, true, min_priority,
                      max_priority);
  proc1_$set_type(new_entry^.level1_pid, 2);
  goto done;

cleanup_asid:
  if not proc1_$tst_lock(ml_$proc2_lock) then
    ml_$lock(ml_$proc2_lock);
  with new_entry^ do begin
    if parent_pgroup_idx <> 0 then
      proc2_$info_table[parent_pgroup_idx].first_child_idx :=
        next_child_sibling;
    if proc2_pf_bound in flags.bits then
      proc1_$unbind(level1_pid, temp_status)
    else if stack <> 0 then
      proc1_$free_stack(stack);
    if status.code <> 16#19 then
      status.fail := true;
    mst_$free_asid(asid, temp_status);
    proc2_$uid[asid] := proc2_$system_uid;
    if cleanup_flags <> [] then
      proc2_$cleanup_handlers_internal(new_entry^);
  end;

cleanup_entry:
  with new_entry^ do begin
    pgroup_cleanup_internal(new_entry^, 2);
    if pad_14 = 0 then
      p2_info_alloc_ptr := next_index
    else
      proc2_$info_table[pad_14].next_index := next_index;
    proc2_$info_table[next_index].pad_14 := pad_14;
    next_index := proc2_$free_list_head;
    proc2_$free_list_head := new_idx;
    parent_uid := uid_$nil;
    flags.bits := flags.bits - [proc2_pf_bound];
    uid := proc2_$system_uid;
  end;
  ml_$unlock(ml_$proc2_lock);
done:
  status_ret := status;
end;
