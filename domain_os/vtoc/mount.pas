{ VTOC_$MOUNT - mount a volume's VTOC.

  Image addresses:
    sau2  0x00E38584  VTOC_$MOUNT

  - The BAT is mounted; then under ml_$vtoc_lock the label's VTOC record
    becomes the volume's, which counts as mounted when its hash size is
    not 0 and its hash type at most 2.
  - A volume found not mounted is dismounted again; the event is
    audited when auditing is on.

  Status stored:
    bat_$mount's status: the VTOC was mounted, or the BAT was not
    status_$vtoc_is_bad: the label's hash size or type is bad
    dbuf_$get_block's status: the label could not be read
}

procedure vtoc_$mount(vol_idx: integer; loc: vtoc_$mount_loc_t;
                      salvage_ok: boolean; write_prot: boolean;
                      out status: status_$t);
var
  rec: vtoc_$mount_audit_t;
  local_status: status_$t;
  bat_status: status_$t;
  event_flags: pinteger;
  label_ptr: bat_$label_ptr_t;
  i: integer;                             { the loops }
begin
  if write_prot then
    disk_$write_protect(disk_$write_protect_set, vol_idx, local_status);
  status.all := status_$ok;
  bat_$mount(vol_idx, salvage_ok, bat_status);
  vtoc_$mounted[vol_idx] := false;

  { the label, under the VTOC lock }
  if (bat_status.all = status_$ok) or else
     (bat_status.all = status_$disk_write_protected) then begin
    ml_$lock(ml_$vtoc_lock);
    label_ptr := dbuf_$get_block(vol_idx, 0, lv_label_$uid, 0, 0, 0,
                                 status);
    if status.all = status_$ok then begin
      vtoc_$vols[vol_idx] := label_ptr^.vtoc_header;
      vtoc_$mounted[vol_idx] := (vtoc_$vols[vol_idx].hash_size <> 0) and
                                (vtoc_$vols[vol_idx].hash_type <= 2);
      vtoc_$format[vol_idx] := label_ptr^.version <> 0;
      vtoc_$cach_wp_flag[vol_idx] := write_prot;
      vtoc_$mount_locs[vol_idx] := loc;

      if audit_$enabled then begin
        rec.uid := label_ptr^.lv_uid;
        for i := 1 to 32 do
          rec.name[i] := label_ptr^.lv_name[i];
        for i := 33 to 36 do
          rec.name[i] := chr(0);
      end;

      dbuf_$set_buff(label_ptr, 10, local_status);
      if local_status.all = status_$disk_write_protected then
        vtoc_$cach_wp_flag[vol_idx] := true;
      if vtoc_$dirty then
        os_disk_proc(0);
      vtoc_$dirty := false;
    end;
    ml_$unlock(ml_$vtoc_lock);

    if status.all = status_$ok then
      if not vtoc_$mounted[vol_idx] then begin
        vtoc_$dismount(vol_idx, true, status);
        bat_$dismount(vol_idx, true, status);
        status.all := status_$vtoc_is_bad;
      end;
  end;

  if status.all = status_$ok then
    status := bat_status;

  { the audit event }
  if audit_$enabled then begin
    rec.write_prot := vtoc_$cach_wp_flag[vol_idx];
    rec.vol_idx := vol_idx;
    rec.loc := loc;
    if status.all = status_$ok then
      event_flags := 0
    else begin
      for i := 1 to 36 do
        rec.name[i] := chr(0);
      rec.uid := uid_$nil;
      event_flags := 1;
    end;
    audit_$log_event(audit_$mount_lv_eu, event_flags, status, rec, 16#32);
  end;
end;
