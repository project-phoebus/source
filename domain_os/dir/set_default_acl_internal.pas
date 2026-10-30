{ dir_$set_default_acl_internal - store one default ACL in a directory's
  root page.

  Image addresses:
    sau2  0x00E52D70  dir_$set_default_acl_internal

  - A "funky" ACL UID is converted by ACL_$CONVERT_FUNKY_ACL, any other
    by ACL_$CONVERT_TO_10ACL; a real ACL object must be local and on the
    directory's volume.
  - A changed default gives the new ACL object a reference, forces the
    page out when asked, and truncates the old object.  Every way out
    goes to the audit log when auditing is on.

  Status stored:
    status_$ok: the default was stored, or unchanged
    acl_$convert_funky_acl's or acl_$convert_to_10acl's status: the
      conversion failed
    ast_$get_location's status: the ACL object could not be located
    file_$objects_on_different_volumes: the ACL object is remote, on
      another volume, or not found
    status_$naming_bad_type: an ACL type other than directory or file
    ast_$set_attribute's or file_$fw_partial's status: that step failed
}

procedure dir_$set_default_acl_internal(var handle: dir_$handle_t;
                                        in acl_type: uid_$t;
                                        in src_acl_uid: uid_$t;
                                        flush: boolean;
                                        out status_ret: status_$t);
  internal;
label
  10;
var
  value: file_$attr_value_t;
  loc: file_$obj_loc_t;
  type_uid: uid_$t;
  new_uid: dir_$uid_view_t;
  prot: acl_$prot_data_t;
  old_uid: dir_$uid_view_t;
  loc_unused: integer32;
  location: ast_$location_t;
  status: status_$t;
  trunc_result: boolean;
  page: dir_$root_page_ptr_t;
  first_byte: integer;
begin
  status_ret.all := status_$ok;
  page := dir_$map_page(handle, 0);

  { the protection and the ACL's UID }
  if (rshft(dir_$uid_view_t(src_acl_uid).w2 & 16#FF0, 4) & 16#E0) <> 0
  then begin
    acl_$convert_funky_acl(src_acl_uid, prot, new_uid.uid, type_uid,
                           status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
    new_uid.low_set := new_uid.low_set - [24];
  end
  else begin
    acl_$convert_to_10acl(src_acl_uid, handle.uid, new_uid.uid, prot,
                          status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
  end;

  { a real ACL object local, on the volume }
  first_byte := new_uid.b0;
  if first_byte <> 0 then begin
    loc.uid := new_uid.uid;
    loc.flags := loc.flags - [6];
    ast_$get_location(loc, 1, loc_unused, location, status);
    if (status.all <> status_$ok) or else (handle.volume <> loc.volume)
       or else (7 in loc.flags) then begin
      status_ret := status;
      if (status_ret.all = file_$object_not_found)
         or else (status_ret.all = status_$ok) then
        status_ret.all := file_$objects_on_different_volumes;
      goto 10;
    end;
  end;

  { into the root page's default }
  if acl_type = acl_$dir_acl then begin
    old_uid.uid := page^.dir_def_prot.acl_uid;
    page^.dir_def_prot.prot := prot;
    if old_uid.uid = new_uid.uid then
      goto 10;
    page^.dir_def_prot.acl_uid := new_uid.uid;
  end
  else if acl_type = acl_$file_acl then begin
    old_uid.uid := page^.file_def_prot.acl_uid;
    page^.file_def_prot.prot := prot;
    if old_uid.uid = new_uid.uid then
      goto 10;
    page^.file_def_prot.acl_uid := new_uid.uid;
  end
  else begin
    status_ret.all := status_$naming_bad_type;
    goto 10;
  end;

  { the new ACL object referenced }
  if first_byte <> 0 then begin
    value.word_val := 1;
    ast_$set_attribute(new_uid.uid, 6, value, status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
  end;

  if flush then begin
    file_$fw_partial(handle.uid, 0, 16#400, status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
  end;

  { the old one truncated }
  if old_uid.b0 <> 0 then
    ast_$truncate(old_uid.uid, 0, 3, trunc_result, status);

10:
  if audit_$enabled then
    audit_$log_prot_op(status_ret, handle.uid, prot, acl_type, new_uid.uid,
                       4);
end;
