{ name_$old_add_link - add a name for an object to an old-format
  directory.

  Image addresses:
    sau2  0x00E5674C  name_$old_add_link

  - The caller needs "add" rights (2); a plain add of an object not
    found goes on.  A remote directory's node adds the link
    (REM_FILE_$NAME_ADD_HARD_LINKU, tried again after a comms failure).
  - Else a local object on the directory's volume gets its link count
    raised (attribute 6), lowered again if the local add fails.
  - A fragment of OLD_DIR.

  Status stored:
    name_$old_add_link_local's status: a local add
    rem_file_$name_add_hard_linku's status: a remote directory
    file_$op_cannot_perform_here: the remote node gave a bad reply
    name_$bad_leaf: a remote add of a name that is not a valid leaf
    the failed step's status: AST_$GET_LOCATION, ACL_$RIGHTS (converted)
      or AST_$SET_ATTRIBUTE
}

procedure name_$old_add_link(in dir_uid: uid_$t;
                             in name: univ name_$long_name_t;
                             name_len: pinteger; in file_uid: uid_$t;
                             hard_link: boolean;
                             out status_ret: status_$t);
  internal;
label
  10;
var
  lock_info: file_$lock_info_t;
  attr_value: file_$attr_value_t;
  parsed: array[1..32] of char;
  loc_dir: file_$obj_loc_t;
  loc_file: file_$obj_loc_t;
  vol_loc: ast_$location_t;
  loc_unused: integer32;
  status2: status_$t;
  status: status_$t;
  parsed_len: pinteger;
  target_exists: boolean;
begin
  { the object }
  loc_file.uid := file_uid;
  loc_file.flags := loc_file.flags - [6];
  target_exists := true;
  ast_$get_location(loc_file, 0, loc_unused, vol_loc, status);

  if status.all <> status_$ok then begin
    if hard_link or else (status.all <> file_$object_not_found) then
      goto 10;
    target_exists := false;
  end;

  { "add" rights on the directory }
  discard(acl_$rights(dir_uid, false, 2, 1, status));
  if status.all <> status_$ok then begin
    name_convert_acl_status(status);
    goto 10;
  end;

  { the directory }
  loc_dir.uid := dir_uid;
  loc_dir.flags := loc_dir.flags - [6];
  ast_$get_location(loc_dir, 0, loc_unused, vol_loc, status);
  if status.all <> status_$ok then
    goto 10;

  { a remote directory }
  if target_exists and then (7 in loc_dir.flags) then begin
    if not name_$validate_leaf(name, name_len, parsed, parsed_len) then
    begin
      status.all := name_$bad_leaf;
      goto 10;
    end;
    rem_file_$name_add_hard_linku(loc_dir.loc_info, dir_uid, parsed,
                                  parsed_len, file_uid, status);
    if status.all = file_$comms_problem_with_remote_node then begin
      file_$read_lock_entryui(dir_uid, lock_info, status2);
      if status2.all = file_$object_not_locked_by_this_process then
        rem_file_$name_add_hard_linku(loc_dir.loc_info, dir_uid, parsed,
                                      parsed_len, file_uid, status);
    end;
    if status.all = file_$bad_reply_received_from_remote_node then
      status.all := file_$op_cannot_perform_here;
    goto 10;
  end;

  { the link count raised }
  attr_value.word_val := 1;
  if ((loc_file.volume = loc_dir.volume) and target_exists)
     and then not (7 in loc_file.flags) then
    ast_$set_attribute(file_uid, 6, attr_value, status);

  if status.all <> status_$ok then
    goto 10;
  name_$old_add_link_local(dir_uid, 0, name, name_len, file_uid, status);
  if status.all <> status_$ok then
    ast_$set_attribute(file_uid, 7, attr_value, status2);

10:
  status_ret := status;
end;
