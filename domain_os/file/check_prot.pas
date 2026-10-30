{ FILE_$CHECK_PROT - check the caller's rights on an object, from its lock
  if it holds one.

  Image addresses:
    sau2  0x00E5D172  FILE_$CHECK_PROT

  - When slot_num names a slot (1..149) of the current address space's
    lock list for this object, the rights recorded with the lock answer
    (unless the entry's bit 4 says they do not speak for the object).
  - Otherwise ACL_$RIGHTS evaluates the object's ACL.  Either way the
    rights go to rights_out.

  Status stored:
    status_$ok: the rights suffice
    status_$no_right_to_perform_operation: the lock's rights are none
    status_$insufficient_rights_to_perform_operation: they are short of
      access_mask
    acl_$rights's status: the ACL was evaluated
}

procedure file_$check_prot(in file_uid: uid_$t; access_mask: pinteger;
                           slot_num: linteger; ignore_super: boolean;
                           option_flags: integer; out rights_out: integer;
                           out status: status_$t);
var
  idx: integer;
  lot_rights: integer;
begin
  status.all := status_$ok;

  { the lock's cached rights }
  if (slot_num <> 0) and then (slot_num < 150) then begin
    idx := file_$lock_table[proc1_$as_id, slot_num];
    if idx <> 0 then
      with file_$lock_entries[idx] do begin
        lot_rights := state.rights;
        rights_out := lot_rights;
        if (uid = file_uid) and then ((lot_rights & 16#10) = 0) then begin
          if lot_rights = 0 then
            status.all := status_$no_right_to_perform_operation
          else if (lot_rights & access_mask) <> access_mask then
            status.all := status_$insufficient_rights_to_perform_operation;
          return;
        end;
      end;
  end;

  { the ACL }
  rights_out := acl_$rights(file_uid, ignore_super, access_mask,
                            option_flags, status);
end;
