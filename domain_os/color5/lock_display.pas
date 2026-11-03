{ COLOR5_$LOCK_DISPLAY - claim the display for a request.

  Image addresses:
    sau8  0x03C806AE  COLOR5_$LOCK_DISPLAY

  - Under the unit's spin lock: a free display (lock state 0) is given
    lock state 5 and the result is true; otherwise false.  kind is not
    read.

  Status stored: none.
}

[section(color5_wired_proc, wired_data)]
function color5_$lock_display(dcte: color5_$dcte_ptr_t;
                              var hw: color5_$hw_t;
                              kind: integer): boolean;
  options(val_param);
var
  info: color5_$info_ptr_t;
  token: pinteger;
begin
  info := dcte^.info;
  token := ml_$spin_lock(info^.lock);
  if hw.lock_state = 0 then begin
    hw.lock_state := 5;
    color5_$lock_display := true;
  end
  else
    color5_$lock_display := false;
  ml_$spin_unlock(info^.lock, token);
end;
