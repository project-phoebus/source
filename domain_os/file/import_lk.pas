{ FILE_$IMPORT_LK - check a lock slot the caller names against an object.

  Image addresses:
    sau2  0x00E603AC  FILE_$IMPORT_LK

  - The calling address space's slot (1..150) must hold a lock object
    table entry of the object; the slot is then handed back.

  Status stored:
    status_$ok: the slot holds the object's lock
    file_$invalid_arg: a slot outside 1..150, empty, or another object's
}

procedure file_$import_lk(in file_uid: uid_$t; in index_in: linteger;
                          out index_out: linteger;
                          out status_ret: status_$t);
var
  e: integer;
begin
  if (index_in = 0) or else (index_in > 16#96) then begin
    status_ret.all := file_$invalid_arg;
    return;
  end;

  e := file_$lock_table[proc1_$as_id, index_in];
  if e = 0 then begin
    status_ret.all := file_$invalid_arg;
    return;
  end;

  if file_uid <> file_$lock_entries[e].uid then begin
    status_ret.all := file_$invalid_arg;
    return;
  end;

  status_ret.all := status_$ok;
  index_out := index_in;
end;
