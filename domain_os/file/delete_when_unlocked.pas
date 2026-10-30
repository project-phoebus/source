{ FILE_$DELETE_WHEN_UNLOCKED - delete an object (FILE_$DELETE's code).

  Image addresses:
    sau2  0x00E5FC3A  FILE_$DELETE_WHEN_UNLOCKED

  - file_$delete_int with the flags 3; the result is its boolean.
  - Nothing waits for the object to be unlocked; the entry passes
    FILE_$DELETE's flags 3.

  Status stored:
    file_$delete_int's status: in either case
}

function file_$delete_when_unlocked(in file_uid: uid_$t;
                                    out status_ret: status_$t): boolean;
var
  result: boolean;
begin
  file_$delete_when_unlocked := file_$delete_int(file_uid, 3, result,
                                                 status_ret);
end;
