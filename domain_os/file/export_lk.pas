{ FILE_$EXPORT_LK - hand one of this process's locks to another process.

  Image addresses:
    sau2  0x00E74110  FILE_$EXPORT_LK

  - Under the table lock the caller's lock entry goes into the target
    process's first free slot (its slot count raised to it if lower) and
    its reference count is bumped; the slot is returned.
  - The slot count's compare is signed (the TODO(pascal) in
    file/priv_unlock_all.pas).

  Status stored:
    status_$ok: the lock was handed over
    proc2_$find_asid's status: the target process was not found
    file_$invalid_arg: a slot number outside 1..150
    file_$object_not_locked_by_this_process: the slot's entry is not in
      use, or not on the object
    file_$local_lock_table_full: the target has no free slot
}

[section(proc2_create_pro, proc2_create_dat)]
procedure file_$export_lk(in file_uid: uid_$t; in lock_index: linteger;
                          in target_proc: uid_$t;
                          out index_out: integer32;
                          out status_ret: status_$t);
var
  current_asid: integer;
  target_asid: integer;
  entry_index: integer;
  slot: integer;
begin
  current_asid := proc1_$as_id;
  target_asid := proc2_$find_asid(target_proc, true, status_ret);
  if status_ret.all <> status_$ok then
    return;

  if (lock_index = 0) or else (lock_index > 16#96) then begin
    status_ret.all := file_$invalid_arg;
    return;
  end;

  entry_index := file_$lock_table[current_asid, lock_index];
  if (entry_index = 0)
     or else (file_$lock_entries[entry_index].state.refcount = 0)
     or else (file_uid <> file_$lock_entries[entry_index].uid) then
    status_ret.all := file_$object_not_locked_by_this_process
  else begin
    status_ret.all := file_$local_lock_table_full;
    ml_$lock(ml_$file_lock_lock);
    for slot := 1 to 150 do
      if file_$lock_table[target_asid, slot] = 0 then begin
        file_$lock_table[target_asid, slot] := entry_index;
        if slot > file_$lock_table2[target_asid] then
          file_$lock_table2[target_asid] := slot;
        file_$lock_entries[entry_index].state.refcount :=
          file_$lock_entries[entry_index].state.refcount + 1;
        status_ret.all := status_$ok;
        index_out := slot;
        exit;
      end;
    ml_$unlock(ml_$file_lock_lock);
  end;
end;
