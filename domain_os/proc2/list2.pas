{ PROC2_$LIST2 - list the UIDs of the level-2 processes from a start index.

  Image addresses:
    sau2  0x00E40402  PROC2_$LIST2

  - Under a cleanup handler and ml_$proc2_lock, slots 1..57 from the
    start index: the bound, listed processes' UIDs, up to the maximum;
    one left out sets the flag and the index to resume from.

  Status stored: none.
}

procedure proc2_$list2(out uid_list: univ proc2_$uid_list_t;
                       in max_count: pinteger;
                       out count: pinteger;
                       in start_index: integer32;
                       out more: boolean;
                       out next_index: integer32);
var
  rec: fim_$cleanup_rec_t;
  cleanup_status: status_$t;
  start: integer32;
  last_copied: integer;
  last_qualified: integer;
  slot: integer;
  found: pinteger;
  max: pinteger;
begin
  max := max_count;
  start := start_index;
  more := false;
  next_index := 0;
  last_qualified := 0;
  last_copied := 0;
  found := 0;
  if max > 57 then
    max := 57;
  cleanup_status := fim_$cleanup(rec);
  if cleanup_status.all = fault_$cleanup_set then begin
    ml_$lock(ml_$proc2_lock);
    for slot := 1 to 57 do
      with proc2_$info_table[slot] do
        if (proc2_pf_bound in flags.bits)
           and then (xpd_pf_debug_target in flags.bits) then begin
          last_qualified := slot;
          if slot >= start then begin
            found := found + 1;
            if found <= max then begin
              uid_list[found] := uid;
              last_copied := slot;
            end;
          end;
        end;
    ml_$unlock(ml_$proc2_lock);
    fim_$rls_cleanup(rec);
    count := found;
    if count < max then
      max := count;
    if last_qualified > last_copied then begin
      more := true;
      next_index := last_copied + 1;
    end;
    if count > max then
      count := max;
  end
  else begin
    fim_$pop_signal(rec);
    ml_$unlock(ml_$proc2_lock);
    count := 0;
  end;
end;
