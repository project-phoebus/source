{ PROC2_$COMPLETE_VFORK - give a vforked child its own address space.

  Image addresses:
    sau2  0x00E73638  PROC2_$COMPLETE_VFORK

  - Under ml_$proc2_lock the reserved alternate ASID is taken, the UIDs
    moved, the initial area and name space mapped (a failure deletes
    the process), and the parent woken.
  - Then the new ASID is switched to, the stack file mapped and the
    program entered through FIM_$PROC2_STARTUP.

  Status stored:
    status_$proc2_process_wasnt_vforked: the caller was not vforked
      (otherwise the routine does not return)
}

{ TODO(pascal) PROC2_$COMPLETE_VFORK's frame has 24 bytes no declared
  object explains

  Stand-ins keep them: unused_30 and unused_34 (8 bytes at a multiple of
  8 from A6 and a longword: one 12-byte object would be placed at a
  multiple of 8, where these bytes do not start) and unused_48 (around
  a compiler word temporary).  Under dpc's rule that an object of 8
  bytes or more sits at a multiple of 8, ctx and uid take their image
  places; what the original declared in the 24 bytes is not known. }

[section(proc2_create_pro, proc2_create_dat)]
procedure proc2_$complete_vfork(in proc_uid: uid_$t;
                                in code_desc: integer32;
                                in map_param: integer32;
                                in entry_point: integer32;
                                in user_data: integer32;
                                in reserved1: integer32;
                                in reserved2: integer32;
                                out status_ret: status_$t);
label
  cleanup;
var
  entry_pc: integer32;
  user_sp: integer32;
  ctx: fim_$startup_context_t;
  uid: uid_$t;
  old_asid: integer;
  idx: integer;
  status: status_$t;
  entry: proc2_info_ptr_t;
  cr: proc2_cr_rec_ptr_t;
  unused_30: array[1..2] of integer32;    { nothing addressed }
  unused_34: integer32;
  map: integer32;
  code: integer32;
  unused_48: array[1..6] of integer;      { around a compiler temporary }
begin
  uid := proc_uid;
  code := code_desc;
  map := map_param;
  entry_pc := entry_point;
  user_sp := user_data;
  ml_$lock(ml_$proc2_lock);
  idx := proc2_$pid_to_index[proc1_$current];
  entry := addr(proc2_$info_table[idx]);
  if not (proc2_pf_alt_asid in entry^.flags.bits) then begin

    status_ret.all := status_$proc2_process_wasnt_vforked;
    ml_$unlock(ml_$proc2_lock);
    return;
  end;
  old_asid := entry^.asid;
  entry^.asid := entry^.asid_alt;
  entry^.asid_alt := 0;
  entry^.cr_rec := user_sp;
  entry^.parent_uid := uid;
  entry^.flags.bits := entry^.flags.bits - [proc2_pf_alt_asid];

  entry^.pad_18[1] := 0;
  proc2_$uid[entry^.asid] := entry^.uid;
  proc2_$uid[old_asid] := proc2_$info_table[entry^.parent_pgroup_idx].uid;

  fim_$fp_init(entry^.asid);
  fim_$user_fim_addr[entry^.asid] := fim_$user_fim_addr[old_asid];

  if fim_$user_fim_addr[entry^.asid] <> 0 then
    fim_$quit_inh[entry^.asid] := false;
  mst_$map_initial_area(code, entry^.asid, uid, map, 7, true, status);

  if status.code <> 0 then
    goto cleanup;
  entry^.stack_uid := uid_$nil;
  name_$init_asid(entry^.asid, status);
  if status.code <> 0 then
    goto cleanup;
  ec_$advance(proc2_$ec[entry^.self_index].fork_ec);
  proc1_$set_asid(entry^.asid);
  ml_$unlock(ml_$proc2_lock);
  cr := proc2_cr_rec_ptr_t(entry^.cr_rec_2);
  cr^.addr_lo := as_$info.stack_file_low;
  cr^.size := as_$info.init_stack_file_size;
  mst_$map_area_at(cr^.addr_lo, cr^.size, 16#4000, true, entry^.stack_uid,
                   cr^.status);
  cr^.stack_uid := entry^.stack_uid;
  if cr^.status.all <> status_$ok then
    proc2_$delete;
  ctx.usp := univ_ptr(user_sp);
  ctx.pc := univ_ptr(entry_pc);
  fim_$proc2_startup(ctx);
cleanup:
  ml_$unlock(ml_$proc2_lock);
  proc2_$delete;
end;
