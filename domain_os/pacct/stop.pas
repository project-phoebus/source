{ PACCT_$STOP - turn accounting off (the system call).

  Image addresses:
    sau2  0x00E5A8C0  PACCT_$STOP

  - The caller must hold a locksmith SID; then, as in PACCT_$SHUTDN,
    the window is unmapped, the file unlocked and the owner UID_$NIL.
  - It has no status parameter: a refusal is stored in its own local.

  Status stored: none.
}

{ TODO(pascal) PACCT_$STOP's 4 frame bytes above exsid

  The stand-in unused_4 holds them.  exsid, 0x64 bytes, is 4 bytes
  below the frame's top, not right below it; PACCT_$START has the same.
  Objects of 8 bytes or more at multiples of 8 would place it so;
  PACCT_$LOG's records, each 4 bytes below where the word rules put it,
  fit the same rule (pacct/log.pas).  dpc aligns frame objects to at
  most 4.  Not settled. }

procedure pacct_$stop;
var
  unused_4: integer32;                    { TODO above }
  exsid: acl_$exsid_t;
  dtv_out: time_$clock_t;
  status: status_$t;
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
