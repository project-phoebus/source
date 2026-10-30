{ dir_$do_op_delete - DIR_$DO_OP's delete and drop-hard-link operations.

  Image addresses:
    sau2  0x00E5125E  dir_$do_op_delete

  - The directory is opened for writing (rights 3) as super-user; the
    deleted-object UID starts as UID_$NIL.
  - A soft link, or a hard link when links are allowed, loses its entry
    only; so does an object not found or on another volume.
  - A directory is only dereferenced (attribute 7); another object is
    locked (FILE_$PRIV_LOCK, mode 4), its entry removed, then deleted.

  Status stored:
    file_$delete_obj's status: the object was deleted
    dir_$remove_entry's status: only the entry went, or its removal
      failed
    dir_$open_dir's status: the directory could not be opened, or (ok)
      a server process (type 9) found the name gone
    name_$not_found: the name is not in the directory
    name_$ill_link_op: a soft link, links not allowed
    ast_$get_common_attributes' status: any failure but "not found"
    status_$no_rights: a reference-counted object with fewer than two
    status_$ast_only_local_access_allowed: a local-only object, to a
      server process
    name_$not_file: not of sub-type 5, 4 or 0, links not allowed
    status_$naming_directory_locked: a directory that is a mount point
    name_$insufficient_rights: the "protected" right without the delete
      right
    name_convert_acl_status' status: another ACL_$RIGHTS failure
    name_$no_rights: the directory's count says unused
    file_$priv_lock's status: the object could not be locked
}

procedure dir_$do_op_delete(in dir_uid: uid_$t;
                            in name: univ name_$long_name_t;
                            name_len: integer; check_del_right: boolean;
                            entry_only: boolean; allow_link: boolean;
                            out entry_uid_ret: uid_$t;
                            out deleted_uid_ret: uid_$t;
                            out status_ret: status_$t);
  internal;
label
  10, 20, 30, 40;
type
  rights_set_t = set of 0..31;
var
  attr_value: file_$attr_value_t;
  scratch_uid: uid_$t;
  loc: file_$obj_loc_t;
  cattr: ast_$common_attr_t;
  lock_slot: linteger;
  ast_status: status_$t;
  entry: dir_$entry_ptr_t;
  handle: dir_$handle_ptr_t;
  find_depth: integer;
  find_extra: integer;
  lock_rights: integer;
  drop_object: boolean;
  deleted: boolean;
  obj_locked: boolean;
  entry_type: integer;
  sub_type: integer;
  rights: rights_set_t;
  n: integer;
begin
  deleted_uid_ret := uid_$nil;

  acl_$enter_super;
  obj_locked := false;
  drop_object := true;
  dir_$open_dir(dir_uid, 2, 3, handle, status_ret);
  acl_$exit_super;
  if status_ret.all <> status_$ok then
    goto 10;

  if not dir_$find_entry(handle^, name, name_len, 0, entry, find_extra,
                         find_depth) then begin
    if proc1_$type[proc1_$current] = 9 then
      goto 10;
    status_ret.all := name_$not_found;
    goto 10;
  end;

  { a soft link }
  entry_type := entry^.flags & 7;
  if entry_type = 4 then begin
    if allow_link then begin
      dir_$remove_entry(handle^, name, name_len, 0, entry_uid_ret,
                        status_ret);
      goto 10;
    end;
    status_ret.all := name_$ill_link_op;
    goto 10;
  end;

  entry_uid_ret := entry^.uid;
  if allow_link and then (entry_type = 3) then
    goto 30;

  { the object }
  loc.uid := entry^.uid;
  loc.flags := loc.flags - [6];
  ast_$get_common_attributes(loc, 16#81, cattr, ast_status);

  if (ast_status.all = status_$ok) and then
     (loc.volume = handle^.volume) then
    goto 40;
  if (ast_status.all <> status_$ok) and then
     (ast_status.all <> file_$object_not_found) then begin
    status_ret := ast_status;
    goto 10;
  end;

30:
  drop_object := obj_locked;
  goto 20;

  { with the attributes }
40:
  if (14 in cattr.access_set) and then (cattr.refcount < 2) then begin
    status_ret.all := status_$no_rights;
    goto 10;
  end;
  if (15 in cattr.access_set) and then
     (proc1_$type[proc1_$current] = 9) then begin
    status_ret.all := status_$ast_only_local_access_allowed;
    goto 10;
  end;

  sub_type := ord(cattr.sub_type);
  if not ((sub_type = 5) or (sub_type = 4) or (sub_type = 0) or
          allow_link) then begin
    status_ret.all := name_$not_file;
    goto 10;
  end;

  { a mount point is not deleted }
  if (sub_type = 2) or else (sub_type = 1) then
    for n := 1 to dir_$mttab.count do
      if loc.uid = dir_$mttab.mount_uid[n] then begin
        status_ret.all := status_$naming_directory_locked;
        goto 10;
      end;

  { the rights }
  rights := rights_set_t(acl_$rights(loc.uid, false, 16#48, -1,
                                     status_ret));
  if (status_ret.all = status_$insufficient_rights_to_perform_operation)
     or else (status_ret.all = status_$ok)
     or else (status_ret.all = status_$no_right_to_perform_operation) then
  begin
    if ((not check_del_right) or not (3 in rights)) and then
       (6 in rights) then begin
      status_ret.all := name_$insufficient_rights;
      goto 10;
    end;
  end
  else begin
    name_convert_acl_status(status_ret);
    goto 10;
  end;

  { a directory: dereferenced only }
  if (sub_type = 2) or else (sub_type = 1) then begin
    attr_value.word_val := 1;
    ast_$set_attribute(loc.uid, 7, attr_value, status_ret);
    if status_ret.all = status_$ast_refcount_says_unused then begin
      status_ret.all := name_$no_rights;
      goto 10;
    end;
    drop_object := false;
    goto 20;
  end;

  { the object locked }
  if not entry_only then begin
    file_$priv_lock(loc.uid, proc1_$as_id, 0, 4, true, 0, 0, 0, 0, 0, 0,
                    0, lock_slot, lock_rights, status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
    obj_locked := true;
  end;

20:
  dir_$remove_entry(handle^, name, name_len, 0, scratch_uid, status_ret);
  if status_ret.all <> status_$ok then
    goto 10;

  dir_$release_handle(handle);
  if drop_object then begin
    file_$delete_obj(loc.uid, true, deleted, status_ret);
    if deleted then
      deleted_uid_ret := loc.uid;
  end;

  if obj_locked then
    discard(file_$unlock_d(loc.uid, lock_slot, 4, ast_status));
  return;

10:
  dir_$release_handle(handle);
end;
