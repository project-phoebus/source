{ ACL_$CONVERT_TO_9ACL - an ACL object for an ACL's 9-entry image.

  Image addresses:
    sau2  0x00E48CE8  ACL_$CONVERT_TO_9ACL

  - With the privilege raised, in the ACL exclusion region and under
    ml_$acl_lock, acl_$image_internal renders the source ACL; a nil
    source gets the caller's default UID as its type and subsystem.
  - A source that can stand gives its own UID, bit 24 of its low half
    cleared; otherwise ACL_$PRIM_CREATE makes a new object.

  Status stored:
    acl_$prim_create's status: a new object was made
    acl_$image_internal's status: the source stands, or could not be
      rendered
}

procedure acl_$convert_to_9acl(in prot: acl_$prot_data_t;
                               in source_uid: uid_$t;
                               in dir_uid: uid_$t;
                               in default_prot: uid_$t;
                               var result_uid: uid_$t;
                               out status_ret: status_$t);
var
  data_out: acl_$prot_data_t;
  len_out: integer;
  flag_out: boolean;
  reusable: boolean;
begin
  acl_$super_count[proc1_$current] := acl_$super_count[proc1_$current] + 1;
  ml_$exclusion_start(acl_$exclusion_lock);
  acl_$locksmith_owner_pid := proc1_$current;
  acl_$locksmith_override := true;
  ml_$lock(ml_$acl_lock);

  acl_$image_internal(source_uid, 1024, true, acl_$workspace, len_out,
                      data_out, flag_out, status_ret);
  reusable := flag_out;
  ml_$unlock(ml_$acl_lock);

  if status_ret.all = status_$ok then begin
    if source_uid = uid_$nil then begin
      acl_$cache_slot_ptr_t(addr(acl_$workspace))^.type_uid := default_prot;
      acl_$cache_slot_ptr_t(addr(acl_$workspace))^.subsys_uid :=
        default_prot;
    end;
    if reusable then begin
      result_uid := source_uid;
      acl_$uid_view_ptr_t(addr(result_uid))^.low_set :=
        acl_$uid_view_ptr_t(addr(result_uid))^.low_set - [24];
    end
    else begin
      result_uid := uid_$nil;
      acl_$prim_create(acl_$workspace, len_out, dir_uid, prot, result_uid,
                       status_ret);
    end;
  end;

  acl_$locksmith_override := false;
  ml_$exclusion_stop(acl_$exclusion_lock);
  acl_$super_count[proc1_$current] := acl_$super_count[proc1_$current] - 1;
end;
