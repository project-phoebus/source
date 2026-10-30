{ FILE_$FORK_LOCK - give a forked process its parent's locks.

  Image addresses:
    sau2  0x00E74244  FILE_$FORK_LOCK

  - Under the table lock every used slot of the current address space's
    lock list is copied to the new address space's, each entry's
    reference count bumped; the new list's count becomes the parent's.

  Status stored:
    status_$ok: always
}

[section(proc2_create_pro, proc2_create_dat)]
procedure file_$fork_lock(in new_asid: integer; out status_ret: status_$t);
var
  parent_asid: integer;
  e: pinteger;
  i: pinteger;                            { the `for' index }
begin
  parent_asid := proc1_$as_id;
  status_ret.all := status_$ok;
  ml_$lock(ml_$file_lock_lock);

  for i := 1 to file_$lock_table2[parent_asid] do begin
    e := file_$lock_table[parent_asid, i];
    if e <> 0 then begin
      file_$lock_table[new_asid, i] := e;
      file_$lock_entries[e].state.refcount :=
        file_$lock_entries[e].state.refcount + 1;
    end;
  end;

  file_$lock_table2[new_asid] := file_$lock_table2[parent_asid];
  ml_$unlock(ml_$file_lock_lock);
end;
