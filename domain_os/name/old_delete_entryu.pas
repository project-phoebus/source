{ name_$old_delete_entryu - delete or drop an old-format directory's
  entry.

  Image addresses:
    sau2  0x00E56B08  name_$old_delete_entryu

  - Only a file, or a link when allowed, with rights 3 on the directory.
    An object not where the directory is loses only its entry.
  - Otherwise the object's rights are checked (16#48), and it is deleted:
    a remote one through REM_FILE_$DROP_HARD_LINKU under a write lock, a
    local one with FILE_$DELETE_OBJ, then the entry unlinked.
  - A fragment of OLD_DIR.

  Status stored:
    name_$old_drop_entry's status: the entry was unlinked
    the unlock's status: a remote object was dropped
    rem_file_$drop_hard_linku's status: the remote drop failed
    name_$ill_link_op: a link, links not allowed
    name_$bad_leaf: another entry type, or a remote name not a valid leaf
    name_convert_acl_status' status: either rights check refused
    the location's or attributes' status: the lookup failed
    name_$not_file: not a file, links not allowed
    name_$insufficient_rights: the protect right without the delete one
    name_$no_rights: a directory with one reference or none
    dir_$old_get_entryu's, file_$priv_lock's or file_$delete_obj's
      status: that step failed
}

procedure name_$old_delete_entryu(in dir_uid: uid_$t;
                                  in name: univ name_$long_name_t;
                                  name_len: pinteger;
                                  check_del_right: boolean;
                                  no_lock: boolean; allow_link: boolean;
                                  out uid_ret: uid_$t;
                                  out status_ret: status_$t);
  internal;
label
  10;
type
  rights_set_t = set of 0..31;
var
  lock_info: file_$lock_info_t;
  cattr: ast_$common_attr_t;
  parsed: array[1..32] of char;
  loc_dir: file_$obj_loc_t;
  loc_obj: file_$obj_loc_t;
  obj_uid: uid_$t;
  entry: dir_$old_entry_t;
  lock_slot: linteger;
  dtv: time_$clock_t;
  vol_loc: ast_$location_t;
  loc_unused: integer32;
  lock_status: status_$t;
  ast_status: status_$t;
  drop_flag: integer;
  parsed_len: pinteger;
  lock_rights: integer;
  del_result: boolean;
  same_location: boolean;
  sub_type: integer;
  rights: rights_set_t;
begin
  { the entry }
  dir_$old_get_entryu(dir_uid, name, name_len, entry, status_ret);
  if status_ret.all <> status_$ok then
    return;

  { a file, or a link if allowed }
  if entry.entry_type <> 1 then
    if entry.entry_type = 3 then begin
      if not allow_link then
        status_ret.all := name_$ill_link_op;
    end
    else
      status_ret.all := name_$bad_leaf;
  if status_ret.all <> status_$ok then
    return;

  { rights on the directory }
  discard(acl_$rights(dir_uid, false, 3, 1, status_ret));
  if status_ret.all <> status_$ok then begin
    name_convert_acl_status(status_ret);
    return;
  end;

  { the directory's location }
  loc_dir.uid := dir_uid;
  loc_dir.flags := loc_dir.flags - [6];
  ast_$get_location(loc_dir, 0, loc_unused, vol_loc, ast_status);
  if ast_status.all <> status_$ok then begin
    status_ret := ast_status;
    return;
  end;

  { the object's }
  obj_uid := entry.uid;
  loc_obj.uid := obj_uid;
  loc_obj.flags := loc_obj.flags - [6];
  same_location := true;
  ast_$get_common_attributes(loc_obj, 16#28, cattr, ast_status);

  { the object not where the directory is }
  sub_type := ord(cattr.sub_type);
  if ((sub_type = 2) and allow_link and (dir_uid = name_$root_uid))
     or else (loc_obj.volume <> loc_dir.volume)
     or else (ast_status.all <> status_$ok)
     or else (loc_obj.node <> loc_dir.node) then begin
    status_ret := ast_status;
    if (status_ret.all <> status_$ok)
       and then (status_ret.all <> file_$object_not_found) then
      return;
    same_location := false;
  end;

  if not same_location then
    goto 10;

  if not allow_link and then (sub_type <> 0) then begin
    status_ret.all := name_$not_file;
    return;
  end;

  { rights on the object }
  rights := rights_set_t(acl_$rights(obj_uid, false, 16#48, -1,
                                     status_ret));
  if (status_ret.all = status_$insufficient_rights_to_perform_operation)
     or else (status_ret.all = status_$ok)
     or else (status_ret.all = status_$no_right_to_perform_operation) then
  begin
    if ((not check_del_right) or not (3 in rights)) and then
       (6 in rights) then begin
      status_ret.all := name_$insufficient_rights;
      return;
    end;
  end
  else begin
    name_convert_acl_status(status_ret);
    return;
  end;

  { a directory with one reference or none }
  if (cattr.refcount <= 1) and then ((sub_type = 1) or else (sub_type = 2))
  then begin
    status_ret.all := name_$no_rights;
    return;
  end;

  { a remote object }
  if 7 in loc_obj.flags then begin
    if not name_$validate_leaf(name, name_len, parsed, parsed_len) then
    begin
      status_ret.all := name_$bad_leaf;
      return;
    end;
    if not no_lock then begin
      file_$priv_lock(obj_uid, proc1_$as_id, 0, 4, false, 0, 0, 0, 0, 0, 0,
                      0, lock_slot, lock_rights, status_ret);
      if status_ret.all <> status_$ok then
        return;
    end;
    if check_del_right then
      drop_flag := 1
    else
      drop_flag := 0;
    rem_file_$drop_hard_linku(loc_obj.loc_info, dir_uid, parsed, parsed_len,
                              drop_flag, status_ret);
    if status_ret.all = file_$comms_problem_with_remote_node then begin
      file_$read_lock_entryui(dir_uid, lock_info, lock_status);
      if lock_status.all = file_$object_not_locked_by_this_process then
        rem_file_$drop_hard_linku(loc_obj.loc_info, dir_uid, parsed,
                                  parsed_len, drop_flag, status_ret);
    end;
    if not no_lock then
      discard(file_$priv_unlock(obj_uid, lock_slot, 4, proc1_$as_id, false,
                                0, 0, 0, dtv, ast_status));
    if status_ret.all <> status_$ok then
      return;
    status_ret := ast_status;
    return;
  end;

  { a local object }
  file_$delete_obj(obj_uid, no_lock, del_result, status_ret);
  if status_ret.all <> status_$ok then
    return;

  { the entry unlinked }
10:
  name_$old_drop_entry(dir_uid, name, name_len, 0, uid_ret, status_ret);
end;
