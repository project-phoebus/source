{ acl_$setids - apply or check an object's set-ID SIDs.

  Image addresses:
    sau2  0x00E46B4E  acl_$setids (module-local)

  - A remote object is asked of its node (REM_FILE_$ACL_SETIDS).
  - Otherwise each owner, group and organization SID with rights bit 5,
    and the image's required subsystem, is copied into sids (set_flag)
    or must be there already.  With no image the login SID is nil.
  - A remote change a restricted local locksmith refuses stores the
    refusal in a local status.

  Status stored:
    status_$ok: the SIDs were applied or held
    acl_$get_obj_acl_attrs' status, fail bit set: the attributes failed
    rem_file_$acl_setids' status: a remote object
    status_$acl_no_right_to_set_subsystem_data: a SID not held, or a
      remote change asked without set_flag
    acl_$find_acl_slot's status: the image could not be found
}

procedure acl_$setids(in uid: uid_$t; set_flag: boolean;
                      var sids: acl_sid_block_t;
                      var owner_ext: acl_proj_list_t;
                      out changed: boolean; out status_ret: status_$t);
  internal;
label
  10;
var
  loc: file_$obj_loc_t;
  attrs: ast_$acl_attr_t;
  status: status_$t;
  slot: integer;
  locked: boolean;
  cached: boolean;
begin
  acl_$get_obj_acl_attrs(uid, loc, attrs, status_ret);
  if status_ret.all <> status_$ok then begin
    status_ret.fail := true;
    return;
  end;

  { a remote object is its node's }
  if not (0 in attrs.obj_flags) and then (7 in loc.flags) then begin
    rem_file_$acl_setids(loc.loc_info, uid, sids, owner_ext, changed,
                         status_ret);
    if (not set_flag) and changed then
      status_ret.all := status_$acl_no_right_to_set_subsystem_data;
    if changed and then (acl_$local_locksmith <> 0) then begin
      changed := false;
      status.all := status_$no_right_to_perform_operation;
    end;
    return;
  end;

  changed := false;
  locked := false;
  status.all := status_$ok;
  slot := -1;
  if (attrs.default_acl <> uid_$nil) or else (attrs.obj_type = 0) then begin
    locked := true;
    ml_$lock(ml_$acl_lock);
    slot := acl_$find_acl_slot(attrs.default_acl, cached, attrs.prot,
                               status);
    if status.all <> status_$ok then
      goto 10;
  end;

  { the owner }
  if (5 in attrs.prot.owner_rights) and then
     (attrs.prot.owner <> uid_$nil) then
    if set_flag then begin
      changed := true;
      sids.user_sid := attrs.prot.owner;
      owner_ext.field_00 := attrs.prot.owner_ext[1];
    end
    else if sids.user_sid <> attrs.prot.owner then begin
      status.all := status_$acl_no_right_to_set_subsystem_data;
      goto 10;
    end;

  { the group }
  if (5 in attrs.prot.group_rights) and then
     (attrs.prot.group <> uid_$nil) then
    if set_flag then begin
      changed := true;
      sids.group_sid := attrs.prot.group;
      owner_ext.field_04 := attrs.prot.owner_ext[2];
    end
    else if sids.group_sid <> attrs.prot.group then begin
      status.all := status_$acl_no_right_to_set_subsystem_data;
      goto 10;
    end;

  { the organization }
  if (5 in attrs.prot.org_rights) and then
     (attrs.prot.org <> uid_$nil) then
    if set_flag then begin
      changed := true;
      sids.org_sid := attrs.prot.org;
      owner_ext.field_08 := attrs.prot.owner_ext[3];
    end
    else if sids.org_sid <> attrs.prot.org then begin
      status.all := status_$acl_no_right_to_set_subsystem_data;
      goto 10;
    end;

  { the image's required-subsystem UID }
  if (slot <> -1) and then
     (acl_$acl_cache[slot].required_uid <> uid_$nil) then begin
    if set_flag then begin
      changed := true;
      sids.login_sid := acl_$acl_cache[slot].required_uid;
    end
    else if sids.login_sid <> acl_$acl_cache[slot].required_uid then begin
      status.all := status_$acl_no_right_to_set_subsystem_data;
      goto 10;
    end;
  end
  else
    sids.login_sid := uid_$nil;

10:
  if locked then
    ml_$unlock(ml_$acl_lock);
  status_ret := status;
end;
