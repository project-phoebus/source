{ dir_$add_bak_default_prot - give a new backup object the directory's
  default file protection and enter it under the original name.

  Image addresses:
    sau2  0x00E50790  dir_$add_bak_default_prot (nested)

  - Nested in dir_$do_op_add_bak, for an original name not in the
    directory; each step runs while the parent's status_ret is ok.

  Status stored: none.
}

procedure dir_$add_bak_default_prot;
var
  prot_uid: uid_$t;
  prot: acl_$prot_data_t;
begin
  dir_$read_def_prot(handle^, acl_$file_acl, prot, prot_uid, status_ret);
  if status_ret.all <> status_$ok then
    return;

  file_$set_prot(uid_data, file_$prot_merge_acl, prot, prot_uid,
                 status_ret);
  if status_ret.all <> status_$ok then
    return;

  dir_$add_entry(handle^, name, name_len, 2, 0, uid_data, 0, '',
                 status_ret);
  if status_ret.all <> status_$ok then
    return;

  rollback := false;
  file_$fw_file(uid, status_ret);
end;
