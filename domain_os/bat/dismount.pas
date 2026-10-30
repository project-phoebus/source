{ BAT_$DISMOUNT - dismount a volume's BAT, writing its label back.

  Image addresses:
    sau2  0x00E3B8BE  BAT_$DISMOUNT

  - Under the BAT lock; the cached bitmap block is released if it is the
    volume's.
  - skip_label clears the volume's total instead of writing the label; a
    write-protected disk or a stopped storage module is forgiven.

  Status stored:
    status_$ok: the label was written back, or skipped
    status_$bat_not_mounted: the volume is not mounted
    dbuf_$get_block's or dbuf_$set_buff's status: the label could not
      be read or written
}

procedure bat_$dismount(vol_idx: integer; skip_label: boolean;
                        out status: status_$t);
label
  done;
var
  local_status: status_$t;
  label_addr: integer32;
begin
  ml_$lock(ml_$bat_lock);
  if vol_idx = bat_$cached_vol then begin
    if bat_$cached_buffer <> nil then
      dbuf_$set_buff(bat_$cached_buffer, bat_$cached_dirty, local_status);
    bat_$cached_buffer := nil;
    bat_$cached_vol := 0;
  end;

  if bat_$mounted[vol_idx] then begin
    bat_$mounted[vol_idx] := false;
    with bat_data[vol_idx] do
      if not skip_label then begin
        label_addr := integer32(dbuf_$get_block(vol_idx, 0, lv_label_$uid,
                                                0, 0, 0, status));
        if status.all <> status_$ok then
          goto done;
        with bat_$label_ptr_t(label_addr)^ do begin
          bat_hdr := hdr;
          if bat_$volume_flags[vol_idx] then
            bat_ptab := ptab;
          mount_time_high := time_$current_clockh;
          current_time := time_$current_clockh;
          salvage_flag := 0;
          dbuf_$set_buff(univ_ptr(label_addr), bat_buf_writeback, status);
        end;
        if (status.all = status_$disk_write_protected)
           or else (status.all = status_$storage_module_stopped) then
          status.all := status_$ok;
      end
      else begin
        hdr.total_blocks := 0;
        status.all := status_$ok;
      end;
  end
  else
    status.all := status_$bat_not_mounted;

done:
  ml_$unlock(ml_$bat_lock);
end;
