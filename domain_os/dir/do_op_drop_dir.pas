{ dir_$do_op_drop_dir - DIR_$DO_OP's handler for operation 16#3A,
  removing an empty subdirectory from its parent.

  Image addresses:
    sau2  0x00E52744  dir_$do_op_drop_dir

  - As super-user, the parent opened for writing with the delete right.
  - A directory on another volume, remote, or not found loses its entry
    only; otherwise it must hold only its stub entry, and its default
    ACLs are truncated and the object deleted before the entry goes.
  - A parent of the old format ("bad directory") is handed to
    DIR_$OLD_DROP_DIRU.

  Status stored:
    dir_$remove_entry's status: the entry was removed
    dir_$open_dir's status: either directory could not be opened
    name_$not_found: the name is not in the parent
    name_$ill_link_op: the name is a soft link
    status_$naming_directory_locked: the directory is a mount's source
    ast_$get_location's status: any failure but "object not found"
    name_$insufficient_rights: ACL_$RIGHTS granted only right 16#40
    acl_$rights' or file_$delete_obj's status: that step failed
    name_$directory_not_empty: more than the stub entry
    dir_$old_drop_diru's status: an old-format parent
}

{ TODO(pascal) open bytes in dir_$do_op_drop_dir's frame

  The SAU2 frame has 21 bytes that no object explains; the register-held
  locals may each keep a slot, their places not known. }

procedure dir_$do_op_drop_dir(in uid: uid_$t;
                              in name: univ name_$long_name_t;
                              name_len: pinteger;
                              out status_ret: status_$t);
  internal;
label
  10;
var
  loc: file_$obj_loc_t;
  acl_uid: uid_$t;
  target_uid: uid_$t;
  removed_uid: uid_$t;
  unused: integer32;
  location: ast_$location_t;
  local_status: status_$t;
  handle: dir_$handle_ptr_t;
  child: dir_$handle_ptr_t;
  entry: dir_$entry_ptr_t;
  depth: integer;
  find_extra: integer;
  delete_result: boolean;
  parent: dir_$handle_ptr_t;
  child_page: dir_$root_page_ptr_t;
  rights: integer;
  n: integer;
begin
  child := nil;
  acl_$enter_super;
  dir_$open_dir(uid, 2, 3, handle, status_ret);
  parent := handle;
  if status_ret.all <> status_$ok then
    goto 10;

  { the entry }
  if not dir_$find_entry(parent^, name, name_len, 0, entry, find_extra,
                         depth) then begin
    status_ret.all := name_$not_found;
    goto 10;
  end;
  if entry^.bits.kind = 4 then begin
    status_ret.all := name_$ill_link_op;
    goto 10;
  end;

  { not a mount's source }
  target_uid := entry^.uid;
  for n := 1 to dir_$mttab.count do
    if target_uid = dir_$mttab.mount_uid[n] then begin
      status_ret.all := status_$naming_directory_locked;
      goto 10;
    end;

  { where the object is }
  loc.uid := target_uid;
  loc.flags := loc.flags - [6];
  ast_$get_location(loc, 1, unused, location, local_status);

  if (loc.volume <> parent^.volume) or else
     (local_status.all <> status_$ok) or else (7 in loc.flags) then begin
    { elsewhere: only the entry }
    status_ret := local_status;
    if (status_ret.all <> status_$ok) and then
       (status_ret.all <> file_$object_not_found) then
      goto 10;
  end
  else begin
    { the right to delete it }
    rights := acl_$rights(target_uid, true, 16#40, 1, status_ret);
    if rights = 16#40 then begin
      status_ret.all := name_$insufficient_rights;
      goto 10;
    end;
    if (status_ret.all <> status_$ok) and then
       (status_ret.all <> status_$no_right_to_perform_operation) and then
       (status_ret.all <>
        status_$insufficient_rights_to_perform_operation) then
      goto 10;

    { the directory itself }
    dir_$open_dir(target_uid, 2, 0, child, status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
    child_page := dir_$map_page(child^, 0);

    if (child_page^.hdr.flags.kind = 0) and then
       ((child_page^.hdr.index_end - (16#12 + child_page^.root_len))
        div 2 = 1) then begin
      { its default ACLs }
      with child_page^ do begin
        if dir_$uid_view_t(dir_def_prot.acl_uid).b0 <> 0 then begin
          acl_uid := dir_def_prot.acl_uid;
          ast_$truncate(acl_uid, 0, 3, delete_result, local_status);
        end;
        if dir_$uid_view_t(file_def_prot.acl_uid).b0 <> 0 then begin
          acl_uid := file_def_prot.acl_uid;
          ast_$truncate(acl_uid, 0, 3, delete_result, local_status);
        end;
      end;

      { the object }
      dir_$unmap_pages(child^);
      file_$delete_obj(target_uid, true, delete_result, status_ret);
      if status_ret.all <> status_$ok then
        goto 10;
    end
    else begin
      status_ret.all := name_$directory_not_empty;
      goto 10;
    end;
  end;

  { the entry }
  dir_$remove_entry(parent^, name, name_len, 2, removed_uid, status_ret);

10:
  dir_$release_handle(handle);
  dir_$release_handle(child);
  acl_$exit_super;
  if status_ret.all = status_$naming_bad_directory then
    dir_$old_drop_diru(uid, name, name_len, status_ret);
end;
