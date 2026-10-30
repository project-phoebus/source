{ NAME_$READ_DIRS_PS - read a process's working and naming directories.

  Image addresses:
    sau2  0x00E588BE  NAME_$READ_DIRS_PS

  - UID_$NIL stands for the calling process; another UID is looked up in
    PROC2_$UID's address spaces 1..57.

  Status stored:
    status_$ok: the process was found
    proc2_$uid_not_found: it was not
}

{ TODO(pascal) 4 frame bytes of NAME_$READ_DIRS_PS no object explains

  In the SAU2 frame, below asid and the loop index's slot, 4 bytes are
  never addressed (stand-in unused_8).  The `for' loop's limit or the
  element offset held in a register would be a candidate only if a
  hidden `for' slot existed, which the other untouched frames
  disfavor. }

procedure name_$read_dirs_ps(in proc_uid: uid_$t; out wdir_uid: uid_$t;
                             out ndir_uid: uid_$t; out status: status_$t);
var
  asid: integer;
  i: integer;
  unused_8: integer32;                    { the TODO above }
begin
  asid := 0;

  { the address space }
  if proc_uid = uid_$nil then
    asid := proc1_$as_id
  else
    for i := 1 to 57 do
      if proc2_$uid[i] = proc_uid then begin
        asid := i;
        exit;
      end;

  if asid = 0 then
    status.all := proc2_$uid_not_found
  else begin
    wdir_uid := name_$wdir_uid[asid];
    ndir_uid := name_$ndir_uid[asid];
    status.all := status_$ok;
  end;
end;
