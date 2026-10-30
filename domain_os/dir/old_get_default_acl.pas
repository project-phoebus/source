{ DIR_$OLD_GET_DEFAULT_ACL - an old-format directory's default ACL.

  Image addresses:
    sau2  0x00E564E6  DIR_$OLD_GET_DEFAULT_ACL

  - An info block refused as illegal, or shorter than 16 bytes, gives
    the system default (ACL_$DEFAULT_ACL of type 1 for directories, 0
    for files); otherwise the block's ACL of the type.

  Status stored:
    status_$ok: the system default was handed back
    status_$naming_bad_type: another ACL type
    dir_$old_read_infoblk's status: the block was read, or failed
}

procedure dir_$old_get_default_acl(in dir_uid: uid_$t; in acl_type: uid_$t;
                                   out acl_ret: uid_$t;
                                   out status_ret: status_$t);
var
  info: dir_$old_info_t;
  info_len: integer;
begin
  dir_$old_read_infoblk(dir_uid, info, 16#28, info_len, status_ret);

  if (status_ret.all = status_$naming_illegal_directory_operation)
     or else (info_len < 16) then begin
    { the system defaults }
    status_ret.all := status_$ok;
    if acl_type = acl_$dir_acl then begin
      acl_ret := acl_$default_acl(1);
    end
    else if acl_type = acl_$file_acl then begin
      acl_ret := acl_$default_acl(0);
    end
    else
      status_ret.all := status_$naming_bad_type;
  end

  { the info block's }
  else if status_ret.code = 0 then begin
    if acl_type = acl_$dir_acl then
      acl_ret := info.dir_acl
    else if acl_type = acl_$file_acl then
      acl_ret := info.file_acl
    else
      status_ret.all := status_$naming_bad_type;
  end;
end;
