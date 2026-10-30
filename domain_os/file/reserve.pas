{ FILE_$RESERVE - reserve disk space for a range of an object.

  Image addresses:
    sau2  0x00E74310  FILE_$RESERVE

  - With the read and write rights (mask 6) on the object, AST_ reserves
    the range; a refusal becomes a FILE_ status (OS_PROC_SHUTWIRED).

  Status stored:
    ast_$reserve's status: the caller has the rights
    acl_$rights's status, made a FILE_ status: the caller has not
}

[section(proc2_create_pro, proc2_create_dat)]
procedure file_$reserve(file_uid: uid_$t; start_byte: integer32;
                        byte_count: integer32; out status_ret: status_$t);
var
  status: status_$t;
begin
  { the read and write rights }
  discard(acl_$rights(file_uid, false, 6, 0, status));

  if status.all = status_$ok then
    ast_$reserve(file_uid, start_byte, byte_count, status)
  else
    os_proc_shutwired(status);

  status_ret := status;
end;
