{ dir_$old_create_obj - create the object of a new old-format directory.

  Image addresses:
    sau2  0x00E54546  dir_$old_create_obj (module-local)

  - Created in the parent (FILE_$PRIV_CREATE), locked (mode 4), mapped
    and its page 0 laid out, both info-block lengths 16.
  - Its default ACLs are the parent's when the parent has fewer than 19
    page slots and an info block of 16 bytes or more, else the system
    defaults; a failure truncates a created object.

  Status stored:
    status_$ok: the object was made
    file_$priv_create's, file_$priv_lock's or mst_$maps' status, fail bit
      set: that step failed
}

procedure dir_$old_create_obj(in parent_uid: uid_$t;
                              parent: dir_$old_dir_ptr_t;
                              dir_type: integer;
                              var new_dir_uid: uid_$t;
                              out status_ret: status_$t);
  internal;
var
  slot: linteger;
  local_status: status_$t;
  dtv: time_$clock_t;
  map_info: integer32;
  rights: integer;
  trunc_result: boolean;
  created: boolean;
  mapped: boolean;
  locked: boolean;
  base: dir_$old_dir_ptr_t;
begin
  created := false;
  mapped := false;
  locked := false;

  discard(file_$priv_create(dir_type, uid_$nil, parent_uid, new_dir_uid,
                            0, 0, nil, status_ret));
  if status_ret.all = status_$ok then begin
    created := true;
    file_$priv_lock(new_dir_uid, proc1_$as_id, 0, 4, false, 16#88, 0, 0, 0,
                    0, 0, 1, slot, rights, status_ret);
    if status_ret.all = status_$ok then begin
      locked := true;
      base := mst_$maps(proc1_$as_id, true, new_dir_uid, 0, 16#7FFF, 16#16,
                        0, true, map_info, status_ret);
      if status_ret.all = status_$ok then begin
        mapped := true;
        dir_$old_init_buf(base^);
        base^.info_write_len := 16;
        base^.info_read_len := 16;
      end;
    end;
  end;

  if mapped then
    mst_$unmap_privi(1, uid_$nil, integer32(base), 16#7FFF, proc1_$as_id,
                     local_status);

  if locked then
    discard(file_$priv_unlock(new_dir_uid, slot, 4, proc1_$as_id, false, 0,
                              0, 0, dtv, local_status));

  if status_ret.all = status_$ok then begin
    { the default ACLs }
    if (parent^.hdr.inline_slots < 19) and then
       (parent^.info_read_len >= 16) then begin
      dir_$old_set_default_acl(new_dir_uid, acl_$file_acl, parent^.file_acl,
                               local_status);
      dir_$old_set_default_acl(new_dir_uid, acl_$dir_acl, parent^.dir_acl,
                               local_status);
    end
    else begin
      dir_$old_set_default_acl(new_dir_uid, acl_$file_acl,
                               acl_$default_acl(0), local_status);
      dir_$old_set_default_acl(new_dir_uid, acl_$dir_acl,
                               acl_$default_acl(dir_type), local_status);
    end;

    dtv.high := 0;
    ast_$cond_flush(new_dir_uid, dtv, local_status);
    if status_ret.all = status_$ok then
      return;
  end;

  { the failure }
  if created then
    ast_$truncate(new_dir_uid, 0, 3, trunc_result, local_status);
  status_ret.fail := true;
end;
