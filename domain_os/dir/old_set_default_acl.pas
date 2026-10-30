{ DIR_$OLD_SET_DEFAULT_ACL - set an old-format directory's default ACL.

  Image addresses:
    sau2  0x00E561CC  DIR_$OLD_SET_DEFAULT_ACL

  - A remote directory goes to its node (REM_FILE_$SET_DEF_ACL).
  - For a local one the info block's ACL of the kind is replaced (NIL by
    the kind's default ACL; a block shorter than 16 bytes first gets the
    system defaults), and the new ACL object gains a reference.
  - The old ACL object, which must be one, is truncated.  Its lookup's
    location flags are not cleared first, unlike the other two.

  Status stored:
    status_$ok: the ACL was set (the last step's status)
    name_convert_acl_status' status: no protection right (mask 8)
    ast_$get_location's status: the directory could not be located
    rem_file_$set_def_acl's status: a remote directory
    status_$naming_illegal_directory_operation: the remote node gave a
      bad reply
    status_$naming_bad_type: an ACL type other than directory or file
    file_$objects_on_different_volumes: the new ACL object is on another
      volume, or not found
    status_$naming_object_is_not_an_acl_object: the old one is not of
      sub-type 3
    a step's status, fail bit set: the new ACL's lookup, the flush, the
      old ACL's attributes or its truncation failed
    the info-block routines' or ast_$set_attribute's status: that step
      failed
}

procedure dir_$old_set_default_acl(in dir_uid: uid_$t; in acl_type: uid_$t;
                                   in acl_uid: uid_$t;
                                   out status_ret: status_$t);
var
  attrs: ast_$common_attr_t;
  value: file_$attr_value_t;
  lv: dir_$old_loc_view_t;
  old_acl: dir_$uid_view_t;
  info: dir_$old_info_t;
  loc_status: status_$t;
  location: ast_$location_t;
  unused: integer32;
  info_len: integer;
  trunc_result: boolean;
  dir_byte: dir_$byte_t;
begin
  discard(acl_$rights(dir_uid, false, 8, 1, status_ret));
  if status_ret.all <> status_$ok then begin
    name_convert_acl_status(status_ret);
    return;
  end;

  lv.loc.uid := dir_uid;
  lv.loc.flags := lv.loc.flags - [6];
  ast_$get_location(lv.loc, 0, unused, location, loc_status);
  if loc_status.all <> status_$ok then begin
    status_ret := loc_status;
    return;
  end;
  dir_byte := lv.byte_1c;

  { a remote directory }
  if 7 in lv.loc.flags then begin
    rem_file_$set_def_acl(lv.loc.loc_info, dir_uid, acl_type, acl_uid,
                          status_ret);
    if status_ret.all = file_$bad_reply_received_from_remote_node then
      status_ret.all := status_$naming_illegal_directory_operation;
    return;
  end;

  dir_$old_read_infoblk(dir_uid, info, 16#28, info_len, status_ret);
  if status_ret.all <> status_$ok then
    return;

  { a short block gets the defaults }
  if info_len < 16 then begin
    if acl_type = acl_$dir_acl then begin
      info.file_acl := acl_$default_acl(0);
      info.dir_acl := acl_$nil;
    end
    else begin
      info.dir_acl := acl_$default_acl(1);
      info.file_acl := acl_$nil;
    end;
    info_len := 16;
  end;

  if acl_type = acl_$dir_acl then begin
    old_acl.uid := info.dir_acl;
    if acl_uid = acl_$nil then
      info.dir_acl := acl_$dndcal
    else
      info.dir_acl := acl_uid;
  end
  else if acl_type = acl_$file_acl then begin
    old_acl.uid := info.file_acl;
    if acl_uid = acl_$nil then
      info.file_acl := acl_$fndwrx
    else
      info.file_acl := acl_uid;
  end
  else begin
    status_ret.all := status_$naming_bad_type;
    return;
  end;

  { a new ACL object, on the directory's volume }
  if dir_$uid_view_t(acl_uid).b0 <> 0 then begin
    lv.loc.uid := acl_uid;
    lv.loc.flags := lv.loc.flags - [6];
    ast_$get_location(lv.loc, 1, unused, location, status_ret);
    if status_ret.all <> status_$ok then begin
      if status_ret.all <> file_$object_not_found then begin
        status_ret.fail := true;
        return;
      end;
      status_ret.all := file_$objects_on_different_volumes;
      return;
    end
    else if lv.byte_1c <> dir_byte then begin
      status_ret.all := file_$objects_on_different_volumes;
      return;
    end;
    value.word_val := 1;
    ast_$set_attribute(acl_uid, 6, value, status_ret);
    if status_ret.all <> status_$ok then
      return;
  end;

  dir_$old_write_infoblk(dir_uid, info, info_len, status_ret);
  if status_ret.all <> status_$ok then
    return;
  file_$fw_partial(dir_uid, 0, 16#400, status_ret);
  if status_ret.all <> status_$ok then begin
    status_ret.fail := true;
    return;
  end;

  { the old ACL object truncated }
  if old_acl.b0 = 0 then
    return;
  lv.loc.uid := old_acl.uid;
  ast_$get_common_attributes(lv.loc, 8, attrs, loc_status);
  if loc_status.all <> status_$ok then begin
    status_ret := loc_status;
    status_ret.fail := true;
    return;
  end;
  if ord(attrs.sub_type) <> 3 then begin
    status_ret.all := status_$naming_object_is_not_an_acl_object;
    return;
  end;
  ast_$truncate(old_acl.uid, 0, 3, trunc_result, loc_status);
  if loc_status.all <> status_$ok then begin
    status_ret := loc_status;
    status_ret.fail := true;
  end;
end;
