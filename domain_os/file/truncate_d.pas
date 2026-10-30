{ FILE_$TRUNCATE_D - truncate an object, with a lock context.

  Image addresses:
    sau2  0x00E73FE4  FILE_$TRUNCATE_D

  - With the write right (2) on the object under the lock context, AST_
    truncates it to the new size; a refusal becomes a FILE_ status
    (OS_PROC_SHUTWIRED).

  Status stored:
    ast_$truncate's status: the caller has the right
    file_$check_prot's status, made a FILE_ status: the caller has not
}

[section(proc2_create_pro, proc2_create_dat)]
procedure file_$truncate_d(in file_uid: uid_$t; in new_size: integer32;
                           in domain_ctx: linteger;
                           out status_ret: status_$t);
var
  rights: integer;
  result: boolean;
begin
  { the write right }
  file_$check_prot(file_uid, 2, domain_ctx, false, 0, rights, status_ret);

  if status_ret.all = status_$ok then
    ast_$truncate(file_uid, new_size, 0, result, status_ret)
  else
    os_proc_shutwired(status_ret);
end;
