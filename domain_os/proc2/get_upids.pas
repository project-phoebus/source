{ PROC2_$GET_UPIDS - return a process's UNIX ids.

  Image addresses:
    sau2  0x00E738A8  PROC2_$GET_UPIDS

  - Under ml_$proc2_lock: the process's own id, its parent's (1 with
    none) and its group's (0 with none), stored whatever the lookup
    answered.

  Status stored:
    proc2_$find_index' status: always
}

[section(proc2_create_pro, proc2_create_dat)]
procedure proc2_$get_upids(proc_uid: uid_$t;
                           out upid: pinteger;
                           out uppid: pinteger;
                           out upgid: pinteger;
                           out status_ret: status_$t);
var
  status: status_$t;
  idx: integer;
  found_upid: integer;
  found_uppid: integer;
  found_upgid: pinteger;
begin
  ml_$lock(ml_$proc2_lock);
  idx := proc2_$find_index(proc_uid, status);
  if status.all = status_$ok then
    with proc2_$info_table[idx] do begin
      found_upid := upid;
      if parent_pgroup_idx <> 0 then
        found_uppid := proc2_$info_table[parent_pgroup_idx].upid

      else
        found_uppid := 1;
      if pgroup_table_idx <> 0 then
        found_upgid := proc2_$pgroup_table[pgroup_table_idx].upgid

      else
        found_upgid := 0;
    end;
  ml_$unlock(ml_$proc2_lock);
  upid := found_upid;
  uppid := found_uppid;
  upgid := found_upgid;
  status_ret := status;
end;
