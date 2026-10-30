{ DIR_$OLD_DROP_DIRU - remove a subdirectory from an old-format directory.

  Image addresses:
    sau2  0x00E5734C  DIR_$OLD_DROP_DIRU

  - The caller needs rights 2 to the parent and 16#40 to the directory
    (the two "no right" statuses of the second check count as success).
  - Under the directory's lock (mode 4) its emptiness is tested and its
    maximum entry count cleared; an empty one loses its default ACLs
    and is dropped, remotely (REM_FILE_$DROP_HARD_LINKU) or locally.

  Status stored:
    name_$old_drop_entry's or rem_file_$drop_hard_linku's status: the
      directory was dropped
    dir_$old_get_entryu's status: the lookup failed
    name_$ill_link_op: the name is a soft link
    name_convert_acl_status' status: the rights were refused, or right
      16#40 alone was granted
    name_$lock_dir's or name_$unlock_dir's status: the lock failed
    name_$directory_not_empty: the directory holds entries
    name_$bad_leaf: a remote directory's name is not a valid leaf
    the failed step's status: dir_$old_set_default_acl,
      ast_$get_location or file_$delete_obj
}

procedure dir_$old_drop_diru(in dir_uid: uid_$t;
                             in name: univ name_$long_name_t;
                             in name_len: pinteger;
                             out status_ret: status_$t);
var
  parsed: array[1..32] of char;
  location: file_$obj_loc_t;
  drop_uid: uid_$t;
  entry: dir_$old_entry_t;
  vol_loc: ast_$location_t;
  loc_unused: integer32;
  handle: dir_$old_dir_ptr_t;
  parsed_len: pinteger;
  del_result: boolean;
  is_empty: boolean;
  rights: integer;
begin
  dir_$old_get_entryu(dir_uid, name, name_len, entry, status_ret);
  if status_ret.all <> status_$ok then
    return;

  if entry.entry_type = 3 then begin
    status_ret.all := name_$ill_link_op;
    return;
  end;

  { the rights to the parent and the directory }
  discard(acl_$rights(dir_uid, true, 2, 1, status_ret));
  if status_ret.all = status_$ok then begin
    drop_uid := entry.uid;
    rights := acl_$rights(drop_uid, true, 16#40, 1, status_ret);
    if rights = 16#40 then
      status_ret.all := status_$insufficient_rights_to_perform_operation
    else if (status_ret.all = status_$no_right_to_perform_operation)
         or else (status_ret.all =
                  status_$insufficient_rights_to_perform_operation) then
      status_ret.all := status_$ok;
  end;

  if status_ret.all <> status_$ok then begin
    name_convert_acl_status(status_ret);
    return;
  end;

  name_$lock_dir(drop_uid, handle, 4, 0, status_ret);
  with handle^ do
    if status_ret.all = status_$ok then begin
      is_empty := entries_used = 0;
      if is_empty then
        max_entries := 0;

      name_$unlock_dir(status_ret);
      if status_ret.code = 0 then
        if is_empty then begin
          { the default ACLs }
          dir_$old_set_default_acl(drop_uid, acl_$file_acl, uid_$nil,
                                   status_ret);
          if status_ret.code = 0 then begin
            dir_$old_set_default_acl(drop_uid, acl_$dir_acl, uid_$nil,
                                     status_ret);
            if status_ret.code = 0 then begin
              location.uid := drop_uid;
              location.flags := location.flags - [6];
              ast_$get_location(location, 1, loc_unused, vol_loc,
                                status_ret);
              if status_ret.all = status_$ok then
                if 7 in location.flags then begin
                  { remote }
                  if not name_$validate_leaf(name, name_len, parsed,
                                             parsed_len) then
                    status_ret.all := name_$bad_leaf
                  else
                    rem_file_$drop_hard_linku(location.loc_info, dir_uid,
                                              parsed, parsed_len, 0,
                                              status_ret);
                end
                else begin
                  { local }
                  file_$delete_obj(drop_uid, true, del_result, status_ret);
                  if status_ret.all = status_$ok then
                    name_$old_drop_entry(dir_uid, name, name_len, 0,
                                         drop_uid, status_ret);
                end;
            end;
          end;
        end
        else
          status_ret.all := name_$directory_not_empty;
    end;

  acl_$exit_super;
end;
