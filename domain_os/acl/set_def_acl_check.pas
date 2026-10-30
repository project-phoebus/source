{ ACL_$SET_DEF_ACL_CHECK - may this ACL be a directory's default ACL?

  Image addresses:
    sau2  0x00E48BF8  ACL_$SET_DEF_ACL_CHECK

  - A nil ACL is accepted at once, the status not written.
  - Otherwise, with the privilege raised, in the ACL exclusion region and
    under ml_$acl_lock, acl_$image_internal renders the ACL; it is
    accepted when its type UID is the caller's.

  Status stored:
    acl_$image_internal's status: the ACL was rendered, or failed
    status_$acl_wrong_type: the image is of another type
}

function acl_$set_def_acl_check(dir_uid: uid_$t;
                                in prot_data: acl_$prot_data_t;
                                in acl_uid: uid_$t;
                                in unused_4: integer;
                                in acl_type: uid_$t;
                                out status_ret: status_$t): boolean;
var
  data_out: acl_$prot_data_t;
  len_out: integer;
  flag_out: boolean;
begin
  acl_$set_def_acl_check := false;

  { a nil ACL is accepted as it is }
  if acl_uid = uid_$nil then begin
    acl_$set_def_acl_check := true;
    return;
  end;

  acl_$super_count[proc1_$current] := acl_$super_count[proc1_$current] + 1;
  ml_$exclusion_start(acl_$exclusion_lock);
  acl_$locksmith_owner_pid := proc1_$current;
  acl_$locksmith_override := true;
  ml_$lock(ml_$acl_lock);

  acl_$image_internal(acl_uid, 1024, true, acl_$workspace, len_out,
                      data_out, flag_out, status_ret);
  ml_$unlock(ml_$acl_lock);

  if status_ret.all = status_$ok then
    if acl_$cache_slot_ptr_t(addr(acl_$workspace))^.type_uid =
       acl_type then
      acl_$set_def_acl_check := true
    else
      status_ret.all := status_$acl_wrong_type;

  acl_$locksmith_override := false;
  ml_$exclusion_stop(acl_$exclusion_lock);
  acl_$super_count[proc1_$current] := acl_$super_count[proc1_$current] - 1;
end;
