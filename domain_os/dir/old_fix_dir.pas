{ DIR_$OLD_FIX_DIR - rebuild an old-format directory.

  Image addresses:
    sau2  0x00E55C66  DIR_$OLD_FIX_DIR

  - A directory the lock (mode 4, rights 2) finds bad is repaired in
    place when its page is of version 0 or 1: reinitialized, its parent
    UID taken from its attributes.
  - Otherwise its page is copied to a temporary object, the directory
    emptied, and the entries re-added one by one; whatever was set up is
    undone at the end.  Super-user mode is left on every path.

  Status stored:
    dir_$old_dir_readu's status: the entries were re-added
    status_$ok: a bad directory was reinitialized
    status_$naming_bad_directory: a bad directory of another version
    name_$lock_dir's status: any other lock failure
    the failed step's status: mst_$maps, file_$priv_create,
      file_$priv_lock, file_$truncate, name_$unlock_dir,
      file_$priv_unlock or mst_$unmap_privi
}

procedure dir_$old_fix_dir(dir_uid: uid_$t; out status_ret: status_$t);
label
  10;
var
  entry: dir_$readu_entry_t;
  link_uid: uid_$t;
  link_text: name_$long_name_t;
  temp_uid: uid_$t;
  info: dir_$old_info_t;
  loc: file_$obj_loc_t;
  attrs: file_$attributes_t;
  lock_slot: linteger;
  cont: dir_$readu_cont_t;
  count: linteger;
  map_info: integer32;
  local_status: status_$t;
  dtv: time_$clock_t;
  temp_va: integer32;
  handle: dir_$old_dir_ptr_t;
  info_len: integer;
  link_len: integer;
  rights: integer;
  mapped: dir_$old_dir_ptr_t;
  temp_created: boolean;
  temp_mapped: boolean;
  dir_locked: boolean;
begin
  name_$lock_dir(dir_uid, handle, 4, 2, status_ret);

  if status_ret.all <> status_$ok then begin
    { a bad directory repaired in place }
    if status_ret.all = status_$naming_bad_directory then begin
      mapped := mst_$maps(proc1_$as_id, true, dir_uid, 0, 16#10000, 16#16,
                          0, true, map_info, status_ret);
      if status_ret.all = status_$ok then begin
        file_$priv_lock(dir_uid, proc1_$as_id, 0, 4, false, 16#88, 0, 0, 0,
                        0, 0, 1, lock_slot, rights, status_ret);
        if status_ret.all = status_$ok then begin
          if mapped^.hdr.version <= 1 then begin
            dir_$old_init_buf(mapped^);
            file_$get_attributes(dir_uid, 4, 16#90, loc, attrs,
                                 local_status);
            if local_status.all = status_$ok then
              mapped^.parent_uid := attrs.dirptr;
            status_ret.all := status_$ok;
          end
          else
            status_ret.all := status_$naming_bad_directory;
          discard(file_$priv_unlock(dir_uid, lock_slot, 4, proc1_$as_id,
                                    false, 0, 0, 0, dtv, local_status));
          if status_ret.all = status_$ok then
            status_ret := local_status;
        end;
        mst_$unmap_privi(1, dir_uid, integer32(mapped), 16#10000,
                         proc1_$as_id, local_status);
        if status_ret.all = status_$ok then
          status_ret := local_status;
      end;
    end;
  end
  else begin
    { the temporary object }
    temp_created := false;
    dir_locked := true;
    temp_mapped := false;
    discard(file_$priv_create(1, uid_$nil, dir_uid, temp_uid, 0, 0, nil,
                              status_ret));
    if status_ret.all <> status_$ok then
      goto 10;
    temp_created := true;
    file_$priv_lock(temp_uid, proc1_$as_id, 0, 4, false, 16#88, 0, 0, 0, 0,
                    0, 1, lock_slot, rights, status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
    mapped := mst_$maps(proc1_$as_id, true, temp_uid, 0, 16#10000, 16#16,
                        0, true, map_info, status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
    temp_mapped := true;

    { the directory copied out and emptied }
    mapped^ := handle^;
    file_$truncate(dir_uid, 0, status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
    dir_$old_init_buf(handle^);
    name_$unlock_dir(status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
    dir_locked := false;
    discard(file_$priv_unlock(temp_uid, lock_slot, 4, proc1_$as_id, false,
                              0, 0, 0, dtv, status_ret));
    if status_ret.all <> status_$ok then
      goto 10;
    mst_$unmap_privi(1, temp_uid, integer32(mapped), 16#10000, proc1_$as_id,
                     status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
    temp_mapped := false;

    { the info block }
    dir_$old_read_infoblk(temp_uid, info, 16#28, info_len, status_ret);
    if status_ret.all = status_$ok then
      dir_$old_write_infoblk(dir_uid, info, info_len, status_ret);

    { the entries replayed }
    cont.all := 1;
    repeat
      dir_$old_dir_readu(temp_uid, cont, 1, 16#116, entry, count,
                         status_ret);
      if (status_ret.all <> status_$ok) or else (count = 0) then
        exit;
      case entry.enttype of
        name_$file: begin
          if name_$root_uid = dir_uid then
            dir_$old_root_addu(dir_uid, entry.entname, entry.entlen,
                               entry.entuid, entry.entextra, local_status)
          else
            dir_$old_addu(dir_uid, entry.entname, entry.entlen,
                          entry.entuid, local_status);
        end;
        name_$link: begin
          dir_$old_read_linku(temp_uid, entry.entname, entry.entlen,
                              link_text, link_len, link_uid, local_status);
          if local_status.all = status_$ok then
            dir_$old_add_linku(dir_uid, entry.entname, entry.entlen,
                               link_text, link_len, local_status);
        end;
      end;
    until false;

    { the undo }
10:
    if temp_mapped then begin
      temp_va := integer32(mapped);
      mst_$unmap(temp_uid, temp_va, 16#10000, local_status);
    end;
    if temp_created then
      file_$set_refcnt(temp_uid, 0, local_status);
    if dir_locked then
      name_$unlock_dir(local_status);
  end;

  acl_$exit_super;
end;
