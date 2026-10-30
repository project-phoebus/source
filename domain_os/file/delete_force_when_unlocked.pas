{ FILE_$DELETE_FORCE_WHEN_UNLOCKED - delete an object (FILE_$DELETE's
  code again).

  Image addresses:
    sau2  0x00E5FC64  FILE_$DELETE_FORCE_WHEN_UNLOCKED

  - file_$delete_int with the flags 3; the result is its boolean.
  - The "force" entry passes the flags 3.

  Status stored:
    file_$delete_int's status: in either case
}

function file_$delete_force_when_unlocked(in file_uid: uid_$t;
                                          out status_ret: status_$t):
  boolean;
var
  result: boolean;
begin
  file_$delete_force_when_unlocked := file_$delete_int(file_uid, 3, result,
                                                       status_ret);
end;
