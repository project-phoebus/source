{ CAL_$READ_TIMEZONE - load the timezone record from the boot volume label.

  Image addresses:
    sau2  0x00E3E520  CAL_$READ_TIMEZONE

  - On a node with a disk the label refreshes CAL_$TIMEZONE's UTC offset
    and name and CAL_$LAST_VALID_TIME (the drift is not on the disk),
    read with the process lock ml_$area_lock set.
  - DBUF_$SET_BUFF's status is not looked at.

  Status stored:
    status_$ok: tz_out holds the record
    dbuf_$get_block's status: the label could not be read
}

procedure cal_$read_timezone(out tz_out: cal_$timezone_rec_t;
                             out status: status_$t);
var
  lbl: bat_$label_ptr_t;
  st: status_$t;
  vol: integer;
begin
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

    cal_$timezone.utc_delta := lbl^.utc_delta;
    cal_$timezone.tz_name := lbl^.tz_name;
    cal_$last_valid_time := lbl^.last_valid_time;

    dbuf_$set_buff(lbl, dbuf_flag_release, st);
    proc1_$clr_lock(ml_$area_lock);
  end;

  tz_out := cal_$timezone;
  status.all := status_$ok;
end;
