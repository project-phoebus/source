{ PROC2_$SET_PGROUP - move a process into a process group (setpgid).

  Image addresses:
    sau2  0x00E410C8  PROC2_$SET_PGROUP

  - Under ml_$proc2_lock the caller may move itself, or a child not an
    orphan (unless debugged) in its session; a non-zero group must not be
    asked by a session leader and must exist in the caller's session
    unless it is the target's own id.

  Status stored:
    pgroup_set_internal's status: the process was moved
    proc2_$find_index' status: the lookup failed (a zombie too)
    proc2_$uid_not_found: not the caller or its child
    status_$proc2_permission_denied: an orphaned child
    status_$proc2_pgroup_in_different_session: the group rules refuse
}

procedure proc2_$set_pgroup(proc_uid: uid_$t; in new_upgid: integer;
                            out status_ret: status_$t);
label
  different_session, done;
var
  uid: uid_$t;
  status: status_$t;
  upgid: integer;
  target_idx: integer;
  pgroup_idx: integer;
  current: proc2_info_ptr_t;
  target: proc2_info_ptr_t;
begin
  uid := proc_uid;
  upgid := new_upgid;
  ml_$lock(ml_$proc2_lock);
  target_idx := proc2_$find_index(uid, status);
  if status.all <> status_$ok then
    goto done;
  current := addr(proc2_$info_table[
               proc2_$pid_to_index[proc1_$current]]);
  target := addr(proc2_$info_table[target_idx]);
  if current^.self_index <> target^.self_index then begin
    if current^.self_index <> target^.parent_pgroup_idx then begin

      status.all := proc2_$uid_not_found;
      goto done;
    end;
    if (proc2_pf_orphan in target^.flags.bits)
       and then not (proc2_pf_debug in target^.flags.bits) then begin

      status.all := status_$proc2_permission_denied;
      goto done;
    end;
    if target^.session_id <> current^.session_id then
      goto different_session;
  end;
  if upgid <> 0 then begin
    if target^.session_id = target^.upid then
      goto different_session;
    if (upgid <> 0) and then (upgid <> target^.upid) then begin

      pgroup_idx := pgroup_find_by_upgid(upgid);
      if (proc2_$pgroup_table[pgroup_idx].session_id
          <> current^.session_id)
         or else (pgroup_idx = 0) then begin
      different_session:
        status.all := status_$proc2_pgroup_in_different_session;

        goto done;
      end;
    end;
  end;
  pgroup_set_internal(target^, upgid, status);
  if upgid = 0 then
    target^.session_id := 0;
done:
  ml_$unlock(ml_$proc2_lock);
  status_ret := status;
end;
