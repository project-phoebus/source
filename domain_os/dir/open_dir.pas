{ dir_$open_dir - open a directory: a handle, its lock and its checks.

  Image addresses:
    sau2  0x00E4BA02  dir_$open_dir

  - Mode 0 is "write, and repair" (lock mode 2); a repair open ignores
    dir_$validate_pages' "internal error".
  - A directory longer than one page whose last page is in the segment
    map is checked under a write lock; a read open goes back to a read
    lock.  Every failure after the allocation releases the handle.
  - The segment-map test reads bit last_page mod 32.

  Status stored:
    status_$ok: the directory was opened (the last step's status)
    status_$naming_directory_locked: no handle was free
    dir_$lock_obj's or dir_$validate_handle's status: that step failed
    name_convert_acl_status' status, failure bit cleared: the rights
      were refused
    status_$naming_directory_object_not_found: ACL_$RIGHTS found no
      object
    status_$naming_bad_directory: page 0 is not of format 5
    ast_$get_seg_map's status: the segment map could not be read
    status_$naming_cant_recovery_dir_on_ro_vol: a write lock on a
      read-only volume
    dir_$validate_pages' status: the pages are damaged
}

procedure dir_$open_dir(in uid: uid_$t; mode: integer; rights: pinteger;
                        var handle_ret: dir_$handle_ptr_t;
                        out status_ret: status_$t);
  internal;
label
  10;
var
  local_uid: uid_$t;
  seg_map: ast_$seg_map_t;
  location: integer32;
  seg_status: status_$t;
  lock_mode: integer;
  repair: boolean;
  handle: dir_$handle_ptr_t;
  page: dir_$page_hdr_ptr_t;
  last_page: pinteger;
  bit: pinteger;
begin
  { mode 0 is a write open that repairs }
  lock_mode := mode;
  if lock_mode = 0 then begin
    lock_mode := 2;
    repair := true;
  end
  else
    repair := false;

  handle_ret := dir_$alloc_handle;
  if handle_ret = nil then begin
    status_ret.all := status_$naming_directory_locked;
    return;
  end;

  handle := handle_ret;
  handle^.uid := uid;

  dir_$lock_obj(handle^, lock_mode, status_ret);
  if status_ret.all <> status_$ok then
    goto 10;
  dir_$validate_handle(handle^, lock_mode, status_ret);
  if status_ret.all <> status_$ok then
    goto 10;

  { the rights asked for }
  if rights <> 0 then begin
    discard(acl_$rights(uid, true, rights, 1, status_ret));
    if status_ret.all <> status_$ok then begin
      name_convert_acl_status(status_ret);
      status_ret.fail := false;
      if status_ret.all = file_$object_not_found then
        status_ret.all := status_$naming_directory_object_not_found;
      goto 10;
    end;
  end;

  { page 0 must be a directory page }
  page := dir_$map_page(handle^, 0);
  if page^.flags.format <> 5 then begin
    status_ret.all := status_$naming_bad_directory;
    goto 10;
  end;

  if handle^.length <= 1024 then
    return;

  { is the last page in the segment map? }
  last_page := handle^.length div 1024 - 1;
  location := 0;
  local_uid := handle^.uid;
  ast_$get_seg_map(local_uid, last_page * 1024, location, 1, 16#20, [1],
                   seg_map, seg_status);
  if seg_status.all <> status_$ok then begin
    status_ret := seg_status;
    goto 10;
  end;

  bit := last_page mod 32;
  if not (bit in seg_map[bit div 32]) then
    return;

  { a read lock becomes a write lock }
  if handle^.lock_mode = 1 then begin
    dir_$unlock_obj(handle^);
    dir_$unmap_pages(handle^);
    dir_$lock_obj(handle^, 2, status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
    dir_$validate_handle(handle^, 2, status_ret);
    if status_ret.all <> status_$ok then begin
      if status_ret.all = status_$naming_vol_mounted_read_only then
        status_ret.all := status_$naming_cant_recovery_dir_on_ro_vol;
      goto 10;
    end;
  end;

  { check the pages }
  dir_$validate_pages(handle^, not repair, status_ret);
  if status_ret.all <> status_$ok then
    if repair and then (status_ret.all = status_$naming_internal_error) then
      status_ret.all := status_$ok
    else
      goto 10;

  { a read open goes back to a read lock }
  if lock_mode = 1 then begin
    dir_$unlock_obj(handle^);
    dir_$unmap_pages(handle^);
    dir_$lock_obj(handle^, 1, status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
    dir_$validate_handle(handle^, lock_mode, status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
  end;
  return;

10:
  dir_$release_handle(handle_ret);
end;
