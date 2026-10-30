{ FILE_$DELETE_FORCE - delete an object (the same flags as FILE_$DELETE).

  Image addresses:
    sau2  0x00E5DB7A  FILE_$DELETE_FORCE

  - The "force" entry passes FILE_$DELETE's flags 3.

  Status stored:
    file_$delete_int's status: in either case
}

function file_$delete_force(in file_uid: uid_$t;
                            out status_ret: status_$t): boolean;
var
  result: boolean;
begin
  file_$delete_force := file_$delete_int(file_uid, 3, result, status_ret);
end;
