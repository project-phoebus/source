{ PROC2_$MAKE_ORPHAN - detach a process from its parent.

  Image addresses:
    sau2  0x00E40D1A  PROC2_$MAKE_ORPHAN
    sau9  0x3C44816A  PROC2_$MAKE_ORPHAN

  - Under ml_$proc2_lock the process (a zombie too) is found, its
    previous sibling looked up (a list ending before it crashes the
    system) and proc2_$detach_from_parent unlinks it.

  Status stored:
    status_$ok: the process was detached
    proc2_$find_index' status: no such process
    status_$proc2_already_orphan: it has no parent
}

procedure proc2_$make_orphan(proc_uid: uid_$t;
                             out status_ret: status_$t);
var
  status: status_$t;
  idx: integer;
  prev: integer;
begin
  ml_$lock(ml_$proc2_lock);
  idx := proc2_$find_index(proc_uid, status);
  if status.all = status_$proc2_zombie then
    status.all := status_$ok;
  if status.all = status_$ok then
    with proc2_$info_table[idx] do begin
      prev := parent_pgroup_idx;
      if prev = 0 then
        status.all := status_$proc2_already_orphan
      else begin
        prev := proc2_$info_table[prev].first_child_idx;
        if prev = idx then
          prev := 0
        else
          while proc2_$info_table[prev].next_child_sibling
                <> self_index do begin
            prev := proc2_$info_table[prev].next_child_sibling;

            if prev = 0 then
              crash_system(status_$proc2_internal_error);
          end;
        proc2_$detach_from_parent(idx, prev);
      end;
    end;
  ml_$unlock(ml_$proc2_lock);
  status_ret := status;
end;
