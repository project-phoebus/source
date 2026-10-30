{ FILE_$DELETE - delete an object.

  Image addresses:
    sau2  0x00E5DB50  FILE_$DELETE

  - file_$delete_int with the flags 3; the result is whether the object
    was locked.

  Status stored:
    file_$delete_int's status: in either case
}

function file_$delete(in file_uid: uid_$t; out status: status_$t): boolean;
var
  result: boolean;
begin
  file_$delete := file_$delete_int(file_uid, 3, result, status);
end;
