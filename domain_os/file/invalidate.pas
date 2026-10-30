{ FILE_$INVALIDATE - discard an object's cached pages in a range.

  Image addresses:
    sau2  0x00E75158  FILE_$INVALIDATE

  - With the read and write rights (mask 6) on the object, AST_ discards
    the pages, waiting or not as the flag says; a refusal becomes a
    FILE_ status (OS_PROC_SHUTWIRED).

  Status stored:
    ast_$invalidate's status: the caller has the rights
    acl_$rights's status, made a FILE_ status: the caller has not
}

[section(proc2_delete_pro, proc2_delete_dat)]
procedure file_$invalidate(file_uid: uid_$t; start_page: linteger;
                           page_count: integer32; flags: boolean;
                           out status_ret: status_$t);
var
  status: status_$t;
begin
  { the read and write rights }
  discard(acl_$rights(file_uid, false, 6, 0, status));

  if status.all = status_$ok then
    ast_$invalidate(file_uid, start_page, page_count, flags, status)
  else
    os_proc_shutwired(status);

  status_ret := status;
end;
