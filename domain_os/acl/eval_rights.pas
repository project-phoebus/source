{ acl_$eval_rights - the rights a SID block and project list hold on an
  object, checked against the rights asked for.

  Image addresses:
    sau2  0x00E464B8  acl_$eval_rights (module-local)

  - A super-user call, or a locksmith, gets the asked rights; a
    restricted local locksmith in a server process is the generic user.
    A remote ACL is asked of its node.
  - Else the protection record (no ACL of its own), or the default ACL's
    cached image (acl_$eval_acl_entries) under ml_$acl_lock.  The result
    is the asked rights granted.
  - On the super-user path add_read_exec is read uninitialized.

  Status stored:
    status_$ok: all the asked rights were granted
    status_$no_right_to_perform_operation: none were
    status_$insufficient_rights_to_perform_operation: some were
    acl_$get_obj_acl_attrs' status, fail bit set: the attributes failed
      (not for a locksmith)
    rem_file_$acl_check_rights' status: a remote ACL
    status_$acl_wrong_type: the object's type does not fit the option
    acl_$find_acl_slot's status: the image could not be loaded
}

function acl_$eval_rights(in sids: acl_sid_block_t;
                          in projects: acl_$proj_uids_t;
                          in uid: uid_$t; ignore_super: boolean;
                          required_mask: integer32; option_flags: integer;
                          in_super: boolean; in_subsys: boolean;
                          out status: status_$t): integer32; internal;
type
  sid_ptr_t = ^acl_sid_block_t;
  proj_ptr_t = ^acl_$proj_uids_t;
label
  10, 20, 30, 99;
var
  local_sids: acl_sid_block_t;
  loc: file_$obj_loc_t;
  attrs: ast_$acl_attr_t;
  sid_p: sid_ptr_t;
  proj_p: proj_ptr_t;
  local_status: status_$t;
  remote_rights: integer32;
  result: integer32;
  add_read_exec: boolean;
  cached_flag: boolean;
  is_locksmith: boolean;
  rights: integer32;
  slot: integer;
  obj_type: integer;
  i: integer;                             { the count only }
begin
  { a super-user }
  if in_super and then not ignore_super then
    goto 10;

  { the locksmith, and the local downgrade }
  sid_p := addr(sids);
  proj_p := addr(projects);
  is_locksmith := false;
  add_read_exec := false;
  if (sids.login_sid = acl_$locksmith_uid) or else
     (sids.group_sid = acl_$locksmith_uid) or else
     (sids.user_sid = acl_$locksmith_uid) then begin
    is_locksmith := true;
    if (acl_$local_locksmith <> 0) and then
       (proc1_$type[proc1_$current] = 9) and then
       not acl_$locksmith_override_bitmap[proc1_$current] then begin
      is_locksmith := false;
      local_sids.user_sid := rgyc_$p_user_uid;
      local_sids.group_sid := rgyc_$g_nil_uid;
      local_sids.org_sid := ppo_$nil_org_uid;
      local_sids.login_sid := uid_$nil;
      sid_p := addr(local_sids);
      proj_p := addr(uid_$nil);
      if acl_$local_locksmith = 1 then
        add_read_exec := true;
    end;
  end;

  { the object's attributes }
  result := 0;
  acl_$get_obj_acl_attrs(uid, loc, attrs, status);
  if status.all <> status_$ok then begin
    if is_locksmith then
      goto 10;
    status.fail := true;
    goto 99;
  end;

  { a remote ACL, asked of its node }
  if not (0 in attrs.obj_flags) and then (7 in loc.flags) then begin
    rem_file_$acl_check_rights(loc.loc_info,
                               acl_$current_sids[proc1_$current],
                               acl_$proj_uids[proc1_$current], uid,
                               ignore_super, required_mask, option_flags,
                               in_super, in_subsys, remote_rights, status);
    result := remote_rights;
    goto 99;
  end;

  { a locksmith's own group }
  if is_locksmith and then (option_flags = 0) and then
     (sids.group_sid = acl_$locksmith_uid) then begin
10:
    rights := 16#0F & required_mask;
    goto 20;
  end;

  { the object type against the option }
  obj_type := attrs.sub_type;
  if not ((obj_type = option_flags) or else
          ((option_flags = 1) and (obj_type = 2)) or else
          (option_flags = -1) or else
          ((option_flags = 0) and then
           ((obj_type = 4) or else (obj_type = 5)))) then begin
    status.all := status_$acl_wrong_type;
    goto 99;
  end;

  if is_locksmith then begin
    rights := (-16#51) & required_mask;
    goto 20;
  end;

  { no ACL of its own, the protection record }
  if (attrs.default_acl = uid_$nil) and then (attrs.obj_type <> 0) then begin
    if not (4 in attrs.prot.owner_rights) and then
       (sid_p^.user_sid = attrs.prot.owner) then begin
      rights := acl_$rights_byte_t(attrs.prot.owner_rights);
      goto 20;
    end;
    if not (4 in attrs.prot.group_rights) then begin
      if sid_p^.group_sid = attrs.prot.group then begin
        rights := acl_$rights_byte_t(attrs.prot.group_rights);
        goto 20;
      end;
      if proj_p^[1] <> uid_$nil then
        for i := 1 to 8 do begin
          if proj_p^[i] = uid_$nil then
            exit;
          if proj_p^[i] = attrs.prot.group then begin
            rights := acl_$rights_byte_t(attrs.prot.group_rights);
            goto 20;
          end;
        end;
    end;
    if not (4 in attrs.prot.org_rights) and then
       (sid_p^.org_sid = attrs.prot.org) then begin
      rights := acl_$rights_byte_t(attrs.prot.org_rights);
      goto 20;
    end;
    rights := acl_$rights_byte_t(attrs.prot.world_rights);
    goto 20;
  end;

  { the default ACL's cached image }
  ml_$lock(ml_$acl_lock);
  slot := acl_$find_acl_slot(attrs.default_acl, cached_flag, attrs.prot,
                             local_status);
  if local_status.code <> 0 then begin
    ml_$unlock(ml_$acl_lock);
    goto 30;
  end;

  { the image's subsystem manager }
  if (slot <> -1) and then in_subsys then
    if (sids.login_sid = acl_$acl_cache[slot].subsys_uid) and then
       (not ignore_super or else in_super) then begin
      rights := (-16#51) & required_mask;
      ml_$unlock(ml_$acl_lock);
      goto 20;
    end;

  if slot = -1 then
    rights := acl_$rights_byte_t(attrs.prot.world_rights)
  else
    rights := pinteger(acl_$eval_acl_entries(acl_$acl_cache[slot], sid_p^,
                                             proj_p^, attrs.prot));
  ml_$unlock(ml_$acl_lock);
  rights := rights & (-17);

20:
  if add_read_exec then
    rights := rights ! (5 & required_mask);
  local_status.all := status_$ok;
  if rights = 0 then
    local_status.all := status_$no_right_to_perform_operation
  else if (required_mask & rights) <> required_mask then
    local_status.all := status_$insufficient_rights_to_perform_operation;
  result := required_mask & rights;

30:
  status := local_status;
99:
  acl_$eval_rights := result;
end;
