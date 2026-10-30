{ PROC2_$FIND_INDEX - the process-table index of a process UID.

  Image addresses:
    sau2  0x00E4068E  PROC2_$FIND_INDEX

  Assume we're called with ml_$proc2_lock held.

  - The allocated list is walked for the UID; the result is the index,
    or 0 when nothing matches.

  Status stored:
    status_$ok: a live process
    status_$proc2_zombie: a zombie
    proc2_$uid_not_found: no match
}

function proc2_$find_index(proc_uid: uid_$t;
                           out status_ret: status_$t): integer;
var
  idx: integer;
begin
  idx := p2_info_alloc_ptr;
  if idx <> 0 then
    repeat
      with proc2_$info_table[idx] do begin
        if proc_uid = uid then begin
          if proc2_pf_zombie in flags.bits then
            status_ret.all := status_$proc2_zombie
          else
            status_ret.all := status_$ok;
          proc2_$find_index := idx;
          return;
        end;
        idx := next_index;
      end;
    until idx = 0;
  status_ret.all := proc2_$uid_not_found;
  proc2_$find_index := idx;
end;
