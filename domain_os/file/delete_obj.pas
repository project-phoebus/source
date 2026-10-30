{ FILE_$DELETE_OBJ - delete an object, forced or not, through the
  common delete.

  Image addresses:
    sau2  0x00E5DB12  FILE_$DELETE_OBJ

  - file_$delete_int with the flags 7 (force) or 5, and the caller's
    result.

  Status stored:
    file_$delete_int's status: in either case
}

procedure file_$delete_obj(in file_uid: uid_$t; force: boolean;
                           out result: boolean;
                           out status_ret: status_$t);
var
  unused_28: array[1..40] of char;        { never addressed:
                                            stand-ins, see the
                                            TODO(pascal) in file/file.pas,
                                            FILE_'s frames }
  unused_2c: integer32;
  flags: integer;
begin
  if force then
    flags := 7
  else
    flags := 5;

  discard(file_$delete_int(file_uid, flags, result, status_ret));
end;
