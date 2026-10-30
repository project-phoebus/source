{ FILE_$FW_FILE - force-write an object's modified pages.

  Image addresses:
    sau2  0x00E5E622  FILE_$FW_FILE

  - AST_$PURIFY writes the whole object, with the flags 2 if it is in
    the lock table and 16#8002 if not.

  Status stored:
    ast_$purify's status: in either case
}

procedure file_$fw_file(in file_uid: uid_$t; out status: status_$t);
var
  flags: integer;
  result: boolean;
begin
  if file_$delete_int(file_uid, 0, result, status) then
    flags := 2
  else
    flags := -16#7FFE;                    { 16#8002 }

  ast_$purify(file_uid, flags, 0, 0, 0, status);
end;
