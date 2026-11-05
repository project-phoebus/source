{ MONO_$LOCK_DISPLAY - claim the display for a request.

  Image addresses:
    sau7  0x3C48D6BA  MONO_$LOCK_DISPLAY
    sau8  0x03C80DCA  MONO_$LOCK_DISPLAY

  - Under the unit's spin lock: a free display (lock state 0) is given
    lock state 5 and the result is true; otherwise false.  kind is not
    read.

  Status stored: none.
}

[section(mono_wired_proc, wired_data)]
function mono_$lock_display(dcte: mono_$dcte_ptr_t;
                              var hw: mono_$hw_t;
                              kind: integer): boolean;
  options(val_param);
var
  info: mono_$info_ptr_t;
  token: pinteger;
begin
  info := dcte^.info;
  token := ml_$spin_lock(info^.lock);
  if hw.lock_state = 0 then begin
    hw.lock_state := 5;
    mono_$lock_display := true;
  end
  else
    mono_$lock_display := false;
  ml_$spin_unlock(info^.lock, token);
end;
