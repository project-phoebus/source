{ PACCT_$START - turn accounting on to a file (the system call).

  Image addresses:
    sau2  0x00E5A746  PACCT_$START

  - The caller must hold a locksmith SID (login, group or user).
    Accounting to an earlier file is stopped; the new file is locked
    (mode 4, flags 8) and must be an ordinary file (type 0).

  Status stored:
    file_$get_attr_info's status: the file is the new owner
    acl_$get_exsid's, file_$priv_lock's or file_$get_attr_info's status:
      that step failed
    status_$insufficient_rights_to_perform_operation: no locksmith SID
    status_$no_rights: not an ordinary file
}

procedure pacct_$start(in file_uid: uid_$t; in unused: integer32;
                       out status: status_$t);
var
  unused_4: integer32;                    { pacct/stop.pas's TODO }
  exsid: acl_$exsid_t;
  file_info: file_$attr_info_t;
  loc_rec: file_$obj_loc_t;
  dtv_out: time_$clock_t;
  rights_out: integer;
begin
  { the caller's rights }
  acl_$get_exsid(exsid, status);
  if status.all <> status_$ok then
    return;
  if (exsid.sids.login_sid <> rgyc_$g_locksmith_uid)
     and then (exsid.sids.group_sid <> rgyc_$g_locksmith_uid)
     and then (exsid.sids.user_sid <> rgyc_$g_locksmith_uid) then begin
    status.all := status_$insufficient_rights_to_perform_operation;
    return;
  end;

  { the earlier file }
  if pacct_owner <> uid_$nil then begin
    if pacct_map_ptr <> 0 then
      mst_$unmap_privi(1, uid_$nil, pacct_map_ptr, pacct_map_offset, 0,
                       status);
    pacct_map_ptr := 0;
    pacct_map_offset := 0;
    pacct_buf_remaining := 0;
    discard(file_$priv_unlock(pacct_owner, pacct_lock_handle, 4, 0, false,
                              0, 0, 0, dtv_out, status));
  end;
  pacct_owner := uid_$nil;

  { the new file }
  file_$priv_lock(file_uid, 0, 1, 4, false, 8, 0, 0, 0, 0, 0, 0,
                  pacct_lock_handle, rights_out, status);
  if status.all <> status_$ok then
    return;
  file_$get_attr_info(file_uid, pacct_start_attr_req, file_attr_info_size,
                      loc_rec, file_info, status);
  if status.all <> status_$ok then
    return;
  if file_info.file_type <> 0 then begin
    status.all := status_$no_rights;
    return;
  end;

  pacct_file_pos := file_info.file_len;
  pacct_map_ptr := 0;
  pacct_write_ptr := 0;
  pacct_buf_remaining := 0;
  pacct_owner := file_uid;
end;
