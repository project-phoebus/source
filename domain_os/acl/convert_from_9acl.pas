{ ACL_$CONVERT_FROM_9ACL - an ACL object's image, and its UID marked.

  Image addresses:
    sau2  0x00E48F56  ACL_$CONVERT_FROM_9ACL

  - With the privilege raised, in the ACL exclusion region (the
    locksmith override on) and under ml_$acl_lock, acl_$image_internal
    renders the source ACL and its protection record.
  - The caller's UID gets the source's with bit 24 of its low half set,
    whatever the status.  The second parameter is never read.

  Status stored:
    acl_$image_internal's status: always (not tested)
}

procedure acl_$convert_from_9acl(in source_acl: uid_$t;
                                 in acl_type: uid_$t;
                                 var prot_buf_out: acl_$prot_data_t;
                                 out prot_uid_out: uid_$t;
                                 out status_ret: status_$t);
var
  image_len: integer;
  image_flag: boolean;
begin
  acl_$super_count[proc1_$current] := acl_$super_count[proc1_$current] + 1;
  ml_$exclusion_start(acl_$exclusion_lock);
  acl_$locksmith_owner_pid := proc1_$current;
  acl_$locksmith_override := true;
  ml_$lock(ml_$acl_lock);

  acl_$image_internal(source_acl, 1024, false, acl_$workspace, image_len,
                      prot_buf_out, image_flag, status_ret);
  ml_$unlock(ml_$acl_lock);

  acl_$locksmith_override := false;
  ml_$exclusion_stop(acl_$exclusion_lock);
  acl_$super_count[proc1_$current] := acl_$super_count[proc1_$current] - 1;

  prot_uid_out := source_acl;
  acl_$uid_view_ptr_t(addr(prot_uid_out))^.low_set :=
    acl_$uid_view_ptr_t(addr(prot_uid_out))^.low_set + [24];
end;
