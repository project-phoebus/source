{ PROC2_$PGROUP_INFO - a process group's session and leader state.

  Image addresses:
    sau2  0x00E41DBC  PROC2_$PGROUP_INFO

  - A zero id gives session 0 and "no leader".  Otherwise, under
    ml_$proc2_lock, the group's slot (or through the first entry whose
    UNIX id is the group id) gives its session and whether its leader
    count is 0.

  Status stored:
    status_$ok: a zero id, or the group was found
    proc2_$uid_not_found: it was not
}

procedure proc2_$pgroup_info(in pgroup_id: integer;
                             out session_id_ret: pinteger;
                             out is_leader_ret: boolean;
                             out status_ret: status_$t);
var
  status: status_$t;
  upgid: integer;
  pgroup_idx: integer;
  index: integer;
  session_id: pinteger;
  is_leader: boolean;
begin
  if pgroup_id = 0 then begin
    session_id_ret := 0;
    is_leader_ret := true;
    status_ret.all := status_$ok;
    return;
  end;
  upgid := pgroup_id;
  ml_$lock(ml_$proc2_lock);
  pgroup_idx := pgroup_find_by_upgid(upgid);
  if pgroup_idx = 0 then begin
    index := p2_info_alloc_ptr;
    if index <> 0 then
      repeat
        with proc2_$info_table[index] do begin
          if upid = upgid then begin
            pgroup_idx := pgroup_table_idx;
            exit;
          end;
          index := next_index;
        end;
      until index = 0;
  end;
  if pgroup_idx <> 0 then begin
    session_id := proc2_$pgroup_table[pgroup_idx].session_id;

    is_leader := proc2_$pgroup_table[pgroup_idx].leader_count = 0;

    status.all := status_$ok;
  end
  else
    status.all := proc2_$uid_not_found;
  ml_$unlock(ml_$proc2_lock);
  if status.all = status_$ok then begin
    session_id_ret := session_id;
    is_leader_ret := is_leader;
  end;
  status_ret := status;
end;
