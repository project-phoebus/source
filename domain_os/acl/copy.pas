{ ACL_$COPY - give an object the protection of a source ACL.

  Image addresses:
    sau2  0x00E4930A  ACL_$COPY

  - The protection is the default (a nil source), the source object's
    ACL attributes (FILEIN, DIRIN), or the source directory's default.
  - An "inherit" default is rebuilt from the caller's SIDs and converted
    to a 9-entry ACL.
  - It is applied by the destination type: FILE_$SET_PROT (FILE_$OLD_AP
    for FILE_SUBS refused subsystem data), DIR_$SET_PROTECTION, or
    DIR_$SET_DEF_PROTECTION.

  Status stored:
    the applying routine's status: the protection was built
    ast_$get_acl_attributes', dir_$get_def_protection's or
      acl_$get_re_sids' status: building it failed
}

procedure acl_$copy(in source_acl_uid: uid_$t; in dest_uid: uid_$t;
                    in source_type: uid_$t; in dest_type: uid_$t;
                    out status_ret: status_$t);
type
  uid_pair_t = record
    first: uid_$t;                        { 0x00 }
    second: uid_$t;                       { 0x08 }
  end;
  uid_pair_ptr_t = ^uid_pair_t;
var
  saved_sids: acl_sid_block_t;
  current_sids: acl_sid_block_t;
  temp: acl_$uid_view_t;
  loc: file_$obj_loc_t;
  attr: ast_$acl_attr_t;
  local_status: status_$t;
  prot_type: integer;
begin
  prot_type := 5;

  { the protection to apply }
  if source_acl_uid = uid_$nil then
    acl_$def_acldata(attr.prot, attr.default_acl)
  else if (source_type = acl_$filein_acl) or else
          (source_type = acl_$dirin_acl) then begin
    loc.uid := source_acl_uid;
    loc.flags := loc.flags - [6];
    ast_$get_acl_attributes(loc, 16#21, attr, local_status);
    status_ret := local_status;
    if status_ret.all <> status_$ok then
      return;
  end
  else begin
    dir_$get_def_protection(source_acl_uid, source_type, attr.prot,
                            attr.default_acl, status_ret);
    if status_ret.all <> status_$ok then
      return;
    temp.uid := uid_$nil;
    temp.low_set := temp.low_set + [24];
    if temp.uid = attr.default_acl then begin
      acl_$get_re_sids(saved_sids, current_sids, status_ret);
      if status_ret.all <> status_$ok then
        return;
      uid_pair_ptr_t(addr(attr.prot))^ :=
        uid_pair_ptr_t(addr(current_sids))^;
      attr.prot.owner_rights := [0..3];
      attr.prot.group_rights := [0..2];
      attr.prot.world_rights := attr.prot.group_rights;
      attr.default_acl := uid_$nil;
      acl_$convert_to_9acl(attr.prot, attr.default_acl, source_acl_uid,
                           source_type, attr.default_acl, status_ret);
      prot_type := 6;
    end;
  end;

  { applied by the destination type }
  if dest_type = acl_$file_subs_acl then begin
    if source_type = acl_$filein_acl then
      prot_type := 4;
    file_$set_prot(dest_uid, prot_type, attr.prot, attr.default_acl,
                   status_ret);
    if (status_ret.all & 16#7FFFFFFF) =
       status_$acl_no_right_to_set_subsystem_data then
      file_$old_ap(dest_uid, prot_type, attr.prot, attr.default_acl,
                   status_ret);
  end
  else if dest_type = acl_$filein_acl then begin
    if source_type = acl_$filein_acl then
      prot_type := 4;
    file_$set_prot(dest_uid, prot_type, attr.prot, attr.default_acl,
                   status_ret);
  end
  else if dest_type = acl_$file_merge_acl then
    file_$set_prot(dest_uid, prot_type, attr.prot, attr.default_acl,
                   status_ret)
  else if dest_type = acl_$dirin_acl then begin
    if source_type = acl_$dirin_acl then
      prot_type := 4;
    dir_$set_protection(dest_uid, attr.prot, attr.default_acl, prot_type,
                        status_ret);
  end
  else if dest_type = acl_$dir_merge_acl then
    dir_$set_protection(dest_uid, attr.prot, attr.default_acl, prot_type,
                        status_ret)
  else
    dir_$set_def_protection(dest_uid, dest_type, attr.prot,
                            attr.default_acl, status_ret);
end;
