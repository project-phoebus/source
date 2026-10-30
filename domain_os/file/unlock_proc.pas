{ FILE_$UNLOCK_PROC - release a process's locks on an object.

  Image addresses:
    sau2  0x00E60E3E  FILE_$UNLOCK_PROC

  - UID_$NIL is the caller's own address space; another process's locks
    need the right 8 on the object.
  - A local process's lock slots are released in the given mode; for a
    remote one the lock table is walked and each lock of the object
    taken by its node released by key.
  - The local loop stops at the first release that answers other than
    "not locked".

  Status stored:
    status_$ok: the locks were released, or a process of this node is
      unknown
    proc2_$find_asid's status: the process could not be looked up
    acl_$rights's status, made a FILE_ status: no right 8
    file_$priv_unlock's or file_$read_lock_entryi's status: those failed
}

procedure file_$unlock_proc(in proc_uid: uid_$t; in file_uid: uid_$t;
                            in lock_mode: integer; in param_4: integer32;
                            out status_ret: status_$t);
var
  lock_info: file_$lock_info_t;
  dtv_out: time_$clock_t;
  iter_index: pinteger;
  asid: integer;
  slot: integer;
begin
  { the process's address space }
  if proc_uid = uid_$nil then
    asid := proc1_$as_id
  else begin
    asid := proc2_$find_asid(proc_uid, false, status_ret);
    if status_ret.all <> status_$ok then begin
      if (proc_uid.low & 16#FFFFF) = node_$me then begin
        status_ret.all := status_$ok;
        return;
      end;
      asid := 0;
    end;
  end;

  { the right to release another's locks }
  if asid <> proc1_$as_id then begin
    discard(acl_$rights(file_uid, false, 8, 0, status_ret));
    if status_ret.all <> status_$ok then begin
      os_proc_shutwired(status_ret);
      return;
    end;
  end;

  if asid <> 0 then begin
    for slot := 1 to file_$lock_table2[asid] do begin
      discard(file_$priv_unlock(file_uid, slot, lock_mode, asid, false, 0,
                                0, 0, dtv_out, status_ret));
      if status_ret.all <> file_$object_not_locked_by_this_process then
        exit;
    end;
  end
  else begin
    iter_index := 1;
    repeat
      file_$read_lock_entryi(uid_$nil, iter_index, lock_info, status_ret);
      if ((lock_info.owner_node & 16#FFFFF) = (proc_uid.low & 16#FFFFF))
         and then
         ((status_ret.all = status_$ok) and (lock_info.file_uid = file_uid))
         and then
         ((lock_mode = lock_info.mode) or else (lock_mode = 0)) then begin
        discard(file_$priv_unlock(file_uid, 0, lock_mode, 0, true,
                                  lock_info.sequence, lock_info.context,
                                  lock_info.owner_node, dtv_out,
                                  status_ret));
        if status_ret.all = file_$object_not_locked_by_this_process then
          status_ret.all := status_$ok;
      end;
    until status_ret.all <> status_$ok;
    if status_ret.all = file_$obj_not_locked_by_this_process then
      status_ret.all := status_$ok;
  end;
end;
