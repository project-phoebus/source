{ PROC2_$UID_TO_UPID - the UNIX process id of a process UID.

  Image addresses:
    sau2  0x00E40F6C  PROC2_$UID_TO_UPID

  - Under ml_$proc2_lock the allocated list is walked for the UID; the
    match's UNIX id is handed back.

  Status stored:
    status_$ok: a live process
    status_$proc2_zombie: a zombie
    proc2_$uid_not_found: no match
}

procedure proc2_$uid_to_upid(proc_uid: uid_$t; out upid_ret: pinteger;
                             out status_ret: status_$t);
label
  done;
var
  status: status_$t;
  found_upid: integer;
  idx: integer;
begin
  status.all := status_$ok;
  ml_$lock(ml_$proc2_lock);
  idx := p2_info_alloc_ptr;
  if idx <> 0 then
    repeat
      with proc2_$info_table[idx] do begin
        if uid = proc_uid then begin
          found_upid := upid;
          if proc2_pf_zombie in flags.bits then
            status.all := status_$proc2_zombie;
          goto done;
        end;
        idx := next_index;
      end;
    until idx = 0;
  status.all := proc2_$uid_not_found;
done:
  ml_$unlock(ml_$proc2_lock);
  upid_ret := found_upid;
  status_ret := status;
end;
