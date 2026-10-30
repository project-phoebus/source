{ ACL_$CONVERT_TO_10ACL - an SR10 ACL object for an old ACL.

  Image addresses:
    sau2  0x00E48E02  ACL_$CONVERT_TO_10ACL

  - With the privilege raised, in the ACL exclusion region and under
    ml_$acl_lock, acl_$image_internal renders the source ACL.
  - A plain default image (52 bytes, its type a directory or file ACL
    type) leaves the result nil; any other becomes a new ACL object
    (ACL_$PRIM_CREATE).

  Status stored:
    acl_$prim_create's status: the image was not the plain default
    acl_$image_internal's status: the image could not be rendered, or
      was the plain default
}

procedure acl_$convert_to_10acl(in source_acl: uid_$t;
                                in dir_uid: uid_$t;
                                var result_uid: uid_$t;
                                var acl_data: acl_$prot_data_t;
                                out status_ret: status_$t);
var
  owner: uid_$t;
  image_len: integer;
  image_flag: boolean;
  len: integer;
begin
  result_uid := uid_$nil;

  acl_$super_count[proc1_$current] := acl_$super_count[proc1_$current] + 1;
  ml_$exclusion_start(acl_$exclusion_lock);
  acl_$locksmith_owner_pid := proc1_$current;
  acl_$locksmith_override := true;
  ml_$lock(ml_$acl_lock);

  acl_$image_internal(source_acl, 1024, true, acl_$workspace, image_len,
                      acl_data, image_flag, status_ret);
  len := image_len;
  ml_$unlock(ml_$acl_lock);

  if status_ret.all = status_$ok then begin
    owner := acl_$cache_slot_ptr_t(addr(acl_$workspace))^.type_uid;
    if (len = 52) and then
       ((owner = acl_$dir_acl) or else (owner = acl_$file_acl)) and then
       (acl_$cache_slot_ptr_t(addr(acl_$workspace))^.required_uid =
        uid_$nil) and then
       (owner = acl_$cache_slot_ptr_t(addr(acl_$workspace))^.subsys_uid)
    then
      result_uid := uid_$nil
    else begin
      result_uid := uid_$nil;
      acl_$prim_create(acl_$workspace, image_len, dir_uid, acl_data,
                       result_uid, status_ret);
    end;
  end;

  acl_$locksmith_override := false;
  ml_$exclusion_stop(acl_$exclusion_lock);
  acl_$super_count[proc1_$current] := acl_$super_count[proc1_$current] - 1;
end;
