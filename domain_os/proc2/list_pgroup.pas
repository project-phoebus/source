{ PROC2_$LIST_PGROUP - list the UIDs of a process group's members.

  Image addresses:
    sau2  0x00E401EA  PROC2_$LIST_PGROUP

  - Under a cleanup handler and ml_$proc2_lock the listed members' UIDs,
    up to the maximum (at most 57); the count is capped, 0 after a fault.

  Status stored: none.
}

procedure proc2_$list_pgroup(in pgroup_uid: uid_$t;
                             out uid_list: univ proc2_$uid_list_t;
                             in max_count: pinteger;
                             out count: pinteger);
var
  rec: fim_$cleanup_rec_t;
  cleanup_status: status_$t;
  pgroup_idx: integer;
  idx: integer;
  max: pinteger;
  n: pinteger;
begin
  max := max_count;
  n := 0;
  if max > 57 then
    max := 57;
  cleanup_status := fim_$cleanup(rec);
  if cleanup_status.all = fault_$cleanup_set then begin
    ml_$lock(ml_$proc2_lock);
    pgroup_idx := proc2_$uid_to_pgroup_index(pgroup_uid);
    if pgroup_idx <> 0 then begin
      idx := p2_info_alloc_ptr;
      if idx <> 0 then
        repeat
          with proc2_$info_table[idx] do begin
            if (xpd_pf_debug_target in flags.bits)
               and then (pgroup_table_idx = pgroup_idx) then begin
              n := n + 1;
              if n <= max then
                uid_list[n] := uid;
            end;
            idx := next_index;
          end;
        until idx = 0;
    end;
    ml_$unlock(ml_$proc2_lock);
    fim_$rls_cleanup(rec);
    count := n;
    if count < max then
      max := count;
    if count > max then
      count := max;
  end
  else begin
    fim_$pop_signal(rec);
    ml_$unlock(ml_$proc2_lock);
    count := 0;
  end;
end;
