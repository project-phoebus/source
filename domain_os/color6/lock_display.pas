{ COLOR6_$LOCK_DISPLAY - claim the display for a request.

  Image addresses:
    sau7  0x3C48CDAC  COLOR6_$LOCK_DISPLAY

  - Under the routine's spin lock: a free display (lock state 0) is
    given lock state 5 and the result is true; otherwise false.  kind is
    not read.

  Status stored: none.
}

[section(color6_wired_proc, wired_data)]
function color6_$lock_display(dcte: color6_$dcte_ptr_t;
                              var hw: color6_$hw_t;
                              kind: integer): boolean;
  options(val_param);
var
  lock: static integer32 := 0;              { +0x14 }
  token: pinteger;
begin
  token := ml_$spin_lock(lock);
  if hw.lock_state = 0 then begin
    hw.lock_state := 5;
    color6_$lock_display := true;
  end
  else
    color6_$lock_display := false;
  ml_$spin_unlock(lock, token);
end;
