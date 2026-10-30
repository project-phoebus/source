{ FILE_$UNLOCK - release the calling address space's lock on an object.

  Image addresses:
    sau2  0x00E5FCFC  FILE_$UNLOCK

  - FILE_$UNLOCK_D's shape with the slot 0; FILE_$PRIV_UNLOCK's boolean
    is the result, its clock dropped.

  Status stored:
    file_$priv_unlock's status: in either case
}

function file_$unlock(in file_uid: uid_$t; in lock_mode: integer;
                      out status: status_$t): boolean;
var
  dtv: time_$clock_t;
begin
  file_$unlock := file_$priv_unlock(file_uid, 0, lock_mode, proc1_$as_id,
                                    false, 0, 0, 0, dtv, status);
end;
