{ DISK_$LVUID_TO_VOLX - the volume index of a mounted logical volume.

  Image addresses:
    sau2  0x00E6D134  DISK_$LVUID_TO_VOLX

  - Under MOUNT_LOCK the slots 1..6 are walked for a mounted logical
    volume with the UID; its index is returned.

  Status stored:
    status_$ok: a match
    status_$logical_volume_not_found: none
}

procedure disk_$lvuid_to_volx(lv_uid: uid_$t; out vol_idx: integer;
                              out status: status_$t);
var
  st: status_$t;
  found: integer;
  i: integer;
begin
  ml_$exclusion_start(mount_lock);
  st.all := status_$logical_volume_not_found;
  for i := 1 to 6 do
    if (disk_$dvtbl[i].mount_state = 3) and then
       (disk_$dvtbl[i].lv_start <> 0) and then
       (disk_$dvtbl[i].lv_uid = lv_uid) then begin
      st.all := status_$ok;
      found := i;
      exit;
    end;

  ml_$exclusion_stop(mount_lock);
  vol_idx := found;
  status := st;
end;
