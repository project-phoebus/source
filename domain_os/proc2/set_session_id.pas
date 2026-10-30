{ PROC2_$SET_SESSION_ID - put the calling process into a session.

  Image addresses:
    sau2  0x00E41C42  PROC2_$SET_SESSION_ID

  - Under ml_$proc2_lock the caller leaves its group, takes the session
    id and joins (or makes) the group of that id.

  Status stored:
    pgroup_set_internal's status: the caller was moved
    status_$proc2_pgroup_in_different_session: another non-zero id, the
      caller in a session and a group already
    status_$proc2_process_is_group_leader: its own upid, leading that
      group (without allow_leader)
    status_$proc2_process_using_pgroup_id: another process uses the id
}

procedure proc2_$set_session_id(allow_leader: boolean;
                                new_session: integer;
                                out status_ret: status_$t);
var
  status: status_$t;
  idx: integer;
  pg: integer;
begin
  ml_$lock(ml_$proc2_lock);
  status.all := status_$ok;
  idx := proc2_$pid_to_index[proc1_$current];
  with proc2_$info_table[idx] do begin
    if new_session <> upid then begin
      if (new_session <> 0) and then (session_id <> 0)
         and then (pgroup_table_idx <> 0) then
        status.all := status_$proc2_pgroup_in_different_session;

    end
    else if new_session <> 0 then begin
      pg := pgroup_find_by_upgid(new_session);
      if (pgroup_table_idx <> 0) and then (pgroup_table_idx = pg) then

        begin
          if not allow_leader then
            status.all := status_$proc2_process_is_group_leader;

        end
      else if pg <> 0 then
        status.all := status_$proc2_process_using_pgroup_id;

    end;
    if status.all = status_$ok then begin
      pgroup_cleanup_internal(proc2_$info_table[idx], 2);
      session_id := new_session;
      pgroup_set_internal(proc2_$info_table[idx], new_session, status);

    end;
  end;
  ml_$unlock(ml_$proc2_lock);
  status_ret := status;
end;
