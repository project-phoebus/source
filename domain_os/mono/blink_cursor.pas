{ MONO_$BLINK_CURSOR - blink the cursor once.

  Image addresses:
    sau7  0x3C48D97A  MONO_$BLINK_CURSOR
    sau8  0x03C8108A  MONO_$BLINK_CURSOR

  - Unless flag 10 of the control word is set, the cursor is drawn or
    removed at its position (MONO_$XOR_CURSOR, by whether it is
    painted) and the painted flag toggled.

  Status stored: none.
}

[section(mono_wired_proc, wired_data)]
procedure mono_$blink_cursor(dcte: mono_$dcte_ptr_t;
                               var blink: mono_$blink_t;
                               var hw: mono_$hw_t);
  options(val_param);
begin
  with dcte^.info^.regs^ do
    if not ctl.flag_10 then begin
      discard(mono_$xor_cursor(dcte, hw.cursor_number, hw.cursor_pos,
                                 hw.disp_limits, blink.cursor_painted));
      blink.cursor_painted := not blink.cursor_painted;
    end;
end;
