{ COLOR4_$REL_DISP - release the display after a request.

  Image addresses:
    sau7  0x3C483D28  COLOR4_$REL_DISP
    sau8  0x03C795D4  COLOR4_$REL_DISP

  - The display's lock state is cleared.
  - With flag 13 of the control word set and flag 10 clear, the board
    is given command 16#0A and the cursor shown again (SHOW_CURSOR, at
    no position, cursor -1).

  Status stored: none.
}

procedure color4_$rel_disp(dcte: color4_$dcte_ptr_t;
                           var hw: color4_$hw_t);
  options(val_param);
begin
  hw.lock_state := 0;
  with dcte^.info^.regs^ do
    if ctl.flag_13 and then not ctl.flag_10 then begin
      reg_406 := 16#0A;
      show_cursor(color4_no_pos, -1, true);
    end;
end;
