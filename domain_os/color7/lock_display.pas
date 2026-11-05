{ COLOR7_$LOCK_DISPLAY - claim the display for a request.

  Image addresses:
    sau7  0x3C48CEBA  COLOR7_$LOCK_DISPLAY

  - Under COLOR7_STATIC's spin lock: a free display (lock state 0) is
    given lock state 5 and the result is true; otherwise false.  kind is
    not read.

  Status stored: none.
}

[section(color7_wired_proc, wired_data)]
function color7_$lock_display(dcte: color7_$dcte_ptr_t;
                              var hw: color7_$hw_t;
                              kind: integer): boolean;
  options(val_param);
var
  token: pinteger;
begin
  token := ml_$spin_lock(color7_static.lock);
  if hw.lock_state = 0 then begin
    hw.lock_state := 5;
    color7_$lock_display := true;
  end
  else
    color7_$lock_display := false;
  ml_$spin_unlock(color7_static.lock, token);
end;
