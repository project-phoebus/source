{ FILE_$REMOVE_WHEN_UNLOCKED - delete an object and hand back the
  delete's result byte.

  Image addresses:
    sau2  0x00E5FC8E  FILE_$REMOVE_WHEN_UNLOCKED

  - file_$delete_int with the flags 3 into a local, whose byte is copied
    to the caller's result.
  - The flags are 3, as the other two's.

  Status stored:
    file_$delete_int's status: in either case
}

procedure file_$remove_when_unlocked(in file_uid: uid_$t;
                                     out result: boolean;
                                     out status_ret: status_$t);
var
  local_result: boolean;
begin
  discard(file_$delete_int(file_uid, 3, local_result, status_ret));

  result := local_result;
end;
