{ dir_$read_def_prot - read one of a directory's default protections.

  Image addresses:
    sau2  0x00E51C6A  dir_$read_def_prot

  - ACL_$DIR_ACL gives the protection for new directories, ACL_$FILE_ACL
    the one for new files, each with its default ACL's UID.

  Status stored:
    status_$ok: the protection was handed back
    status_$naming_bad_type: another ACL type
}

procedure dir_$read_def_prot(var handle: dir_$handle_t; in acl_type: uid_$t;
                             out prot_buf: acl_$prot_data_t;
                             out acl_uid_ret: uid_$t;
                             out status_ret: status_$t);
var
  page: dir_$root_page_ptr_t;
begin
  status_ret.all := status_$ok;
  page := dir_$map_page(handle, 0);

  if acl_type = acl_$dir_acl then begin
    prot_buf := page^.dir_def_prot.prot;
    acl_uid_ret := page^.dir_def_prot.acl_uid;
  end
  else if acl_type = acl_$file_acl then begin
    prot_buf := page^.file_def_prot.prot;
    acl_uid_ret := page^.file_def_prot.acl_uid;
  end
  else
    status_ret.all := status_$naming_bad_type;
end;
