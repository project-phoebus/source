{ CAL_$SHUTDOWN - stamp the boot volume's label with the time at shutdown.

  Image addresses:
    sau2  0x00E3E6E4  CAL_$SHUTDOWN

  - TIME_$CLOCKH becomes the label's mount time and last valid time.
  - No lock is taken and NETWORK_$DISKLESS is not tested: the callers
    test it, or NETWORK_$REALLY_DISKLESS, first.

  Status stored:
    dbuf_$set_buff's status: the label was read
    dbuf_$get_block's status: it could not be
}

procedure cal_$shutdown(out status: status_$t);
var
  lbl: bat_$label_ptr_t;
begin
  lbl := dbuf_$get_block(cal_$boot_volx, 0, lv_label_$uid, 0, 0, 0,
                         status);
  if status.all = status_$ok then begin
    lbl^.mount_time_high := time_$clockh;
    lbl^.last_valid_time := lbl^.mount_time_high;
    dbuf_$set_buff(lbl, dbuf_flag_dirty + dbuf_flag_writeback +
                   dbuf_flag_release, status);
  end;
end;
