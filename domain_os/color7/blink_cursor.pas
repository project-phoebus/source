{ COLOR7_$BLINK_CURSOR - blink the cursor once.

  Image addresses:
    sau7  0x3C48D1D4  COLOR7_$BLINK_CURSOR

  - The cursor is drawn or removed at its position (COLOR7_$XOR_CURSOR,
    by whether it is painted), and the painted flag toggled when that
    succeeds.

  Status stored: none.
}

[section(color7_wired_proc, wired_data)]
procedure color7_$blink_cursor(dcte: color7_$dcte_ptr_t;
                               var blink: color7_$blink_t;
                               var hw: color7_$hw_t);
  options(val_param);
begin
  if color7_$xor_cursor(dcte, hw.cursor_number, hw.cursor_pos,
                        hw.disp_limits, blink.cursor_painted) then
    blink.cursor_painted := not blink.cursor_painted;
end;
