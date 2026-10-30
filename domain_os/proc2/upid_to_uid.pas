{ PROC2_$UPID_TO_UID - the UID of a UNIX process id.

  Image addresses:
    sau2  0x00E40ECE  PROC2_$UPID_TO_UID

  - Under ml_$proc2_lock the allocated list is walked for the UNIX id;
    the match's UID is handed back.

  Status stored:
    status_$ok: a live process
    status_$proc2_zombie: a zombie
    proc2_$uid_not_found: no match
}

procedure proc2_$upid_to_uid(in upid: integer; out uid_ret: uid_$t;
                             out status_ret: status_$t);
label
  done;
var
  found: uid_$t;
  status: status_$t;
  search: integer;
  idx: integer;
begin
  search := upid;
  status.all := status_$ok;
  ml_$lock(ml_$proc2_lock);
  idx := p2_info_alloc_ptr;
  if idx <> 0 then
    repeat
      with proc2_$info_table[idx] do begin
        if upid = search then begin
          found := uid;
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
  uid_ret := found;
  status_ret := status;
end;
