{ ACL_$SET_ACL_CHECK - may the caller put this ACL on this object, and
  is it a set-id operation.

  Image addresses:
    sau2  0x00E470C4  ACL_$SET_ACL_CHECK
    sau9  0x3C44E7D4  ACL_$SET_ACL_CHECK

  - A remote object whose ACL is not local is asked of its node
    (REM_FILE_$SET_ACL).  Otherwise the new ACL must be an ACL object,
    and both cached images are found under ml_$acl_lock.
  - A locksmith (but for the local downgrade) is allowed and marked
    super-user; others need the change right and the subsystem rules,
    and a change of the manager or required entry is a set-id one.
  - Unless the operation type is 5, every SID the new record marks as
    changed (rights bit 5) must be one the caller holds.

  Status stored:
    status_$ok: the change is allowed
    acl_$get_obj_acl_attrs' status, fail bit set: either object's
      attributes failed (not a nil ACL's "not found")
    rem_file_$set_acl's status: a remote object
    status_$acl_wrong_type: the ACL is not an ACL object, or the images
      protect different kinds of object
    acl_$rights' or acl_$find_acl_slot's status: that step failed
    status_$acl_object_not_found: the object's ACL is missing
    status_$no_right_to_perform_operation: no change right, or a marked
      SID the caller does not hold
    status_$acl_no_right_to_set_subsystem_data: a subsystem rule refused
}

function acl_$set_acl_check(obj_uid: uid_$t;
                            in new_prot: acl_$prot_data_t;
                            in acl_uid: uid_$t;
                            in op_type: integer;
                            out setid_ret: boolean;
                            out status_ret: status_$t): boolean;
label
  20, 30, 40, 50, 99;
var
  attrs2: ast_$acl_attr_t;
  loc: file_$obj_loc_t;
  attrs1: ast_$acl_attr_t;
  result_status: status_$t;
  proj_count: integer;
  acl_missing: boolean;
  cached_flag: boolean;
  rights: integer32;
  slot1: integer;
  slot2: integer;
  s1: acl_$cache_slot_ptr_t;
  s2: acl_$cache_slot_ptr_t;
  sid: ^uid_$t;
  result: boolean;
  found: boolean;
  i: integer;                             { the remote count's }
begin
  result := false;
  setid_ret := false;

  { the object's attributes }
  acl_$get_obj_acl_attrs(obj_uid, loc, attrs1, status_ret);
  if status_ret.all <> status_$ok then begin
    status_ret.fail := true;
    goto 99;
  end;

  { a remote object, its ACL not local }
  if not (0 in attrs1.obj_flags) and then (7 in loc.flags) then begin
    proj_count := 8;
    for i := 1 to 8 do
      if acl_$proj_uids[proc1_$current][i] = uid_$nil then begin
        proj_count := i - 1;
        exit;
      end;
    rem_file_$set_acl(loc.loc_info, obj_uid, acl_uid, new_prot,
                      acl_$current_sids[proc1_$current],
                      acl_$proj_uids[proc1_$current], proj_count, op_type,
                      status_ret);
    if status_ret.all = status_$ok then
      result := true;
    goto 99;
  end;

  { the ACL object's attributes }
  acl_$get_obj_acl_attrs(acl_uid, loc, attrs2, status_ret);
  if status_ret.all <> status_$ok then
    if (status_ret.all = file_$object_not_found) and then
       (acl_uid = uid_$nil) then
      status_ret.all := status_$ok
    else begin
      status_ret.fail := true;
      goto 99;
    end;

  if attrs2.sub_type <> 3 then begin
    status_ret.all := status_$acl_wrong_type;
    goto 99;
  end;

  { all four rights on the object }
  rights := acl_$rights(obj_uid, false, 16#F, attrs1.sub_type, status_ret);
  if (status_ret.all <> status_$ok) and then
     (status_ret.all <> status_$no_right_to_perform_operation) and then
     (status_ret.all <> status_$insufficient_rights_to_perform_operation)
     then
    goto 99;

  { both cached images, under the ACL lock }
  ml_$lock(ml_$acl_lock);
  if (attrs1.default_acl <> uid_$nil) or else (attrs1.obj_type = 0) then
    begin
    slot1 := acl_$find_acl_slot(attrs1.default_acl, cached_flag,
                                attrs1.prot, status_ret);
    if (status_ret.all <> status_$ok) and then
       (status_ret.all <> status_$acl_object_not_found) then begin
      ml_$unlock(ml_$acl_lock);
      goto 99;
    end;
  end;
  if status_ret.all = status_$acl_object_not_found then
    acl_missing := true
  else
    acl_missing := false;
  if (attrs2.default_acl <> uid_$nil) or else (attrs2.obj_type = 0) then
    begin
    slot2 := acl_$find_acl_slot(attrs2.default_acl, cached_flag,
                                attrs2.prot, status_ret);
    if status_ret.all <> status_$ok then begin
      ml_$unlock(ml_$acl_lock);
      goto 99;
    end;
  end;

  with acl_$current_sids[proc1_$current] do begin
    { a locksmith, but for the local downgrade }
    if (login_sid = acl_$locksmith_uid) or else
       (group_sid = acl_$locksmith_uid) or else
       (user_sid = acl_$locksmith_uid) then
      if (acl_$local_locksmith = 0) or else
         (proc1_$type[proc1_$current] <> 9) or else
         acl_$locksmith_override_bitmap[proc1_$current] then begin
        result := true;
        acl_$asid_suser_bitmap[proc1_$current] := true;
        result_status.all := status_$ok;
        goto 20;
      end;

    if acl_missing then begin
      result_status.all := status_$acl_object_not_found;
      goto 20;
    end;
    result_status.all := status_$no_right_to_perform_operation;
    if (rights & 8) = 0 then
      goto 20;
    result_status.all := status_$acl_no_right_to_set_subsystem_data;

    if (attrs1.default_acl <> uid_$nil) and then
       (attrs2.default_acl <> uid_$nil) then begin
      { both have an image }
      s1 := addr(acl_$acl_cache[slot1]);
      s2 := addr(acl_$acl_cache[slot2]);
      result_status.all := status_$acl_wrong_type;
      if s1^.type_uid <> s2^.type_uid then
        goto 20;
      result_status.all := status_$acl_no_right_to_set_subsystem_data;
      if s1^.subsys_uid <> s2^.subsys_uid then begin
        if not (((s1^.subsys_uid = s1^.type_uid) and then
                 (s2^.subsys_uid = login_sid)) or else
                ((s2^.subsys_uid = s2^.type_uid) and then
                 (s1^.subsys_uid = login_sid))) then
          goto 20;
        setid_ret := true;
      end;
      if s1^.required_uid = s2^.required_uid then
        goto 40;
      if (s1^.required_uid = uid_$nil) and then
         ((s2^.required_uid = login_sid) or else
          (s2^.required_uid = obj_uid)) then
        goto 30;
      if (s2^.required_uid <> uid_$nil) or else
         (s1^.required_uid <> login_sid) then
        goto 20;
      goto 30;
    end
    else if (attrs1.default_acl <> uid_$nil) and then
            (attrs2.default_acl = uid_$nil) then begin
      { only the object has an image }
      if (acl_$acl_cache[slot1].subsys_uid <>
          acl_$acl_cache[slot1].type_uid) and then
         (login_sid <> acl_$acl_cache[slot1].subsys_uid) then
        goto 20;
      if acl_$acl_cache[slot1].required_uid = uid_$nil then
        goto 30;
      if login_sid <> acl_$acl_cache[slot1].required_uid then
        goto 20;
      goto 30;
    end
    else if (attrs1.default_acl = uid_$nil) and then
            (attrs2.default_acl <> uid_$nil) then begin
      { only the ACL object has an image }
      if (acl_$acl_cache[slot2].type_uid = acl_$dir_acl) and then
         not ((attrs1.sub_type = 2) or (attrs1.sub_type = 1)) then begin
        result_status.all := status_$acl_wrong_type;
        goto 20;
      end;
      if (acl_$acl_cache[slot2].type_uid = acl_$file_acl) and then
         not ((attrs1.sub_type = 5) or (attrs1.sub_type = 4) or
              (attrs1.sub_type = 0)) then begin
        result_status.all := status_$acl_wrong_type;
        goto 20;
      end;
      if (acl_$acl_cache[slot2].subsys_uid <>
          acl_$acl_cache[slot2].type_uid) and then
         (login_sid <> acl_$acl_cache[slot2].subsys_uid) then
        goto 20;
      if acl_$acl_cache[slot2].required_uid = uid_$nil then
        goto 30;
      if login_sid = acl_$acl_cache[slot2].required_uid then
        goto 30;
      if acl_$acl_cache[slot2].required_uid <> obj_uid then
        goto 20;
      goto 30;
    end;
  end;
  goto 40;

30:
  setid_ret := true;

  { the SIDs being changed }
40:
  if op_type = 5 then
    goto 50;
  with acl_$current_sids[proc1_$current] do begin
    if not (5 in new_prot.owner_rights) and then
       not (5 in new_prot.group_rights) and then
       not (5 in new_prot.org_rights) then
      goto 50;
    if (acl_$local_locksmith <> 0) and then
       (proc1_$type[proc1_$current] = 9) then
      goto 20;
    setid_ret := true;

    if 5 in new_prot.owner_rights then
      if op_type = 3 then begin
        if attrs1.prot.owner <> user_sid then
          goto 20;
      end
      else if new_prot.owner <> user_sid then
        goto 20;

    if 5 in new_prot.group_rights then begin
      if op_type = 3 then
        sid := addr(attrs1.prot.group)
      else
        sid := addr(new_prot.group);
      if sid^ <> group_sid then begin
        found := false;
        for i := 1 to 8 do begin
          if acl_$proj_uids[proc1_$current][i] = uid_$nil then
            exit;
          if acl_$proj_uids[proc1_$current][i] = sid^ then begin
            found := true;
            exit;
          end;
        end;
        if not found then
          goto 20;
      end;
    end;

    if 5 in new_prot.org_rights then begin
      if op_type = 3 then
        sid := addr(attrs1.prot.org)
      else
        sid := addr(new_prot.org);
      if sid^ <> org_sid then
        goto 20;
    end;
  end;

50:
  result_status.all := status_$ok;
  result := true;

20:
  ml_$unlock(ml_$acl_lock);
  status_ret := result_status;

99:
  acl_$set_acl_check := result;
end;
