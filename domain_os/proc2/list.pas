{ PROC2_$LIST - list the UIDs of the level-2 processes.

  Image addresses:
    sau2  0x00E402F0  PROC2_$LIST

  - Under a cleanup handler and ml_$proc2_lock entry 1's UID, then the
    listed processes' but address space 1's, up to the maximum (at most
    57); the count is capped, 0 after a fault.

  Status stored: none.
}

procedure proc2_$list(out uid_list: univ proc2_$uid_list_t;
                      in max_count: pinteger;
                      out count: pinteger);
var
  rec: fim_$cleanup_rec_t;
  cleanup_status: status_$t;
  idx: integer;
  max: pinteger;
  n: pinteger;
begin
  max := max_count;
  n := 1;
  if max > 57 then
    max := 57;
  cleanup_status := fim_$cleanup(rec);
  if cleanup_status.all = fault_$cleanup_set then begin
    ml_$lock(ml_$proc2_lock);
    if max <> 0 then
      uid_list[1] := proc2_$info_table[1].uid;
    idx := p2_info_alloc_ptr;
    if idx <> 0 then
      repeat
        with proc2_$info_table[idx] do begin
          if (xpd_pf_debug_target in flags.bits)
             and then (asid <> 1) then begin
            n := n + 1;
            if n <= max then
              uid_list[n] := uid;
          end;
          idx := next_index;
        end;
      until idx = 0;
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
