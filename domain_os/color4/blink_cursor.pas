{ COLOR4_$BLINK_CURSOR - blink the cursor once.

  Image addresses:
    sau7  0x3C48BF9E  COLOR4_$BLINK_CURSOR
    sau8  0x03C802BA  COLOR4_$BLINK_CURSOR

  - Unless flag 10 of the control word is set, the cursor is drawn or
    removed at its position (COLOR4_$XOR_CURSOR, by whether it is
    painted) and the painted flag toggled.

  Status stored: none.
}

[section(color4_wired_proc, wired_data)]
procedure color4_$blink_cursor(dcte: color4_$dcte_ptr_t;
                               var blink: color4_$blink_t;
                               var hw: color4_$hw_t);
  options(val_param);
begin
  with dcte^.info^.regs^ do
    if not ctl.flag_10 then begin
      discard(color4_$xor_cursor(dcte, hw.cursor_number, hw.cursor_pos,
                                 hw.disp_limits, blink.cursor_painted));
      blink.cursor_painted := not blink.cursor_painted;
    end;
end;
