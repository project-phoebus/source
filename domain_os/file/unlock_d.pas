{ FILE_$UNLOCK_D - release a lock by its slot for the calling address
  space.

  Image addresses:
    sau2  0x00E5FCC2  FILE_$UNLOCK_D

  - The lock named by the caller's slot and mode goes to
    FILE_$PRIV_UNLOCK for the current address space, not by key; its
    boolean is the result, its clock dropped.

  Status stored:
    file_$priv_unlock's status: in either case
}

function file_$unlock_d(in file_uid: uid_$t; in lock_index: integer32;
                        in lock_mode: integer;
                        out status_ret: status_$t): boolean;
var
  dtv: time_$clock_t;
begin
  file_$unlock_d := file_$priv_unlock(file_uid, lock_index, lock_mode,
                                      proc1_$as_id, false, 0, 0, 0, dtv,
                                      status_ret);
end;
