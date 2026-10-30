{ PROC2_$FIND_ASID - the address space of a process UID.

  Image addresses:
    sau2  0x00E40724  PROC2_$FIND_ASID
    sau9  0x3C447B94  PROC2_$FIND_ASID

  - Under ml_$proc2_lock, PROC2_$FIND_INDEX; the result is the entry's
    asid, or asid_alt when use_alt asks and the entry has one.
  - A failed lookup leaves the result unwritten.

  Status stored:
    proc2_$find_index' status: always
}

function proc2_$find_asid(in proc_uid: uid_$t;
                          in use_alt: boolean;
                          out status_ret: status_$t): integer;
var
  status: status_$t;
  idx: integer;
begin
  ml_$lock(ml_$proc2_lock);
  idx := proc2_$find_index(proc_uid, status);
  if status.all = status_$ok then begin
    if use_alt
       and then (proc2_pf_alt_asid in
                 proc2_$info_table[idx].flags.bits) then
      proc2_$find_asid := proc2_$info_table[idx].asid_alt
    else
      proc2_$find_asid := proc2_$info_table[idx].asid;
  end;
  ml_$unlock(ml_$proc2_lock);
  status_ret := status;
end;
