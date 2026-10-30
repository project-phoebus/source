{ CAL_$WRITE_TIMEZONE - install a timezone record and write it to the
  boot volume label.

  Image addresses:
    sau2  0x00E3E5E0  CAL_$WRITE_TIMEZONE

  - On a node with a disk the label gets the UTC offset, the name, and
    TIME_$CLOCKH as its mount time and last valid time, with the process
    lock ml_$area_lock set.

  Status stored:
    status_$ok: the record was installed (and written)
    cal_$out_of_range: a name character is not printable ASCII nor above
      16#A0
    dbuf_$get_block's or dbuf_$set_buff's status: the label could not be
      read or written
}

procedure cal_$write_timezone(in tz_rec: cal_$timezone_rec_t;
                              out status: status_$t);
var
  lbl: bat_$label_ptr_t;
  st: status_$t;
  i: integer;
  vol: integer;
  c: char;
begin
  { the name's characters }
  for i := 1 to 4 do begin
    c := tz_rec.tz_name[i];
    if (c < ' ') or else ((c > '~') and then (ord(c) <= 16#A0)) then begin
      status.all := cal_$out_of_range;
      return;
    end;
  end;

  cal_$timezone := tz_rec;

  { the label, on a node with a disk }
  if not network_$diskless then begin
    vol := cal_$boot_volx;
    proc1_$set_lock(ml_$area_lock);
    lbl := dbuf_$get_block(vol, 0, lv_label_$uid, 0, 0, 0, st);
    if st.all <> status_$ok then begin
      proc1_$clr_lock(ml_$area_lock);
      status := st;
      return;
    end;

    lbl^.utc_delta := cal_$timezone.utc_delta;
    lbl^.tz_name := cal_$timezone.tz_name;
    lbl^.mount_time_high := time_$clockh;
    lbl^.last_valid_time := lbl^.mount_time_high;

    dbuf_$set_buff(lbl, dbuf_flag_dirty + dbuf_flag_writeback +
                   dbuf_flag_release, st);
    proc1_$clr_lock(ml_$area_lock);

    if st.all <> status_$ok then begin
      status := st;
      return;
    end;
  end;

  status.all := status_$ok;
end;
