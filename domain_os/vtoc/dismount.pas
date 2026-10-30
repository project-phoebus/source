{ VTOC_$DISMOUNT - dismount a volume's VTOC.

  Image addresses:
    sau2  0x00E38764  VTOC_$DISMOUNT

  - Under ml_$vtoc_lock, for a mounted volume: unless forced its VTOC
    record goes back into the label; it is marked not mounted, its
    UID-cache entries dropped, its BAT dismounted, its buffers written.
  - The disk volume is dismounted, and the event audited.
  - The audit record's name and UID are filled only on the unforced
    path.

  Status stored:
    bat_$dismount's status: the volume was mounted
    status_$ok: it was not
}

procedure vtoc_$dismount(vol_idx: integer; force: boolean;
                         out status: status_$t);
var
  rec: vtoc_$dismount_audit_t;
  event_flags: pinteger;
  label_ptr: bat_$label_ptr_t;
  i: integer;                             { the loops }
begin
  status.all := status_$ok;
  ml_$lock(ml_$vtoc_lock);

  if vtoc_$mounted[vol_idx] then begin
    if not force then begin
      label_ptr := dbuf_$get_block(vol_idx, 0, lv_label_$uid, 0, 0, 0,
                                   status);
      if status.all = status_$ok then begin
        label_ptr^.vtoc_header := vtoc_$vols[vol_idx];
        if audit_$enabled then begin
          rec.uid := label_ptr^.lv_uid;
          for i := 1 to 32 do
            rec.name[i] := label_ptr^.lv_name[i];
          for i := 33 to 36 do
            rec.name[i] := chr(0);
        end;
        dbuf_$set_buff(label_ptr, bat_buf_dirty, status);
      end;
    end;
    vtoc_$mounted[vol_idx] := false;
    os_disk_proc(vol_idx);
    bat_$dismount(vol_idx, force, status);
    if status.all = status_$ok then
      dbuf_$update_vol(vol_idx, uid_$nil);
  end;

  ml_$unlock(ml_$vtoc_lock);
  disk_$dismount(vol_idx);

  { the audit event }
  if audit_$enabled then begin
    if status.all = status_$ok then
      event_flags := 0
    else
      event_flags := 1;
    rec.force := force;
    rec.vol_idx := vol_idx;
    audit_$log_event(audit_$dismount_lv_eu, event_flags, status, rec,
                     16#30);
  end;
end;
