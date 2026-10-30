{ PACCT_$SHUTDN - stop accounting at shutdown.

  Image addresses:
    sau2  0x00E5A6C0  PACCT_$SHUTDN

  - With accounting on, the window is unmapped and the file unlocked;
    either way the owner becomes UID_$NIL.

  Status stored: none.
}

procedure pacct_$shutdn;
var
  dtv_out: time_$clock_t;
  status: status_$t;
begin
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
end;
