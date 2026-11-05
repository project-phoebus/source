{ COLOR6_$BLINK_CURSOR - blink the cursor once.

  Image addresses:
    sau7  0x3C48CD02  COLOR6_$BLINK_CURSOR

  - The cursor drawn or removed by its painted state, without waiting,
    and the state flipped.

  Status stored: none.
}

[section(color6_wired_proc, wired_data)]
procedure color6_$blink_cursor(dcte: color6_$dcte_ptr_t;
                               var blink: color6_$blink_t;
                               var hw: color6_$hw_t);
  options(val_param);
begin
  discard(color6_$xor_cursor(dcte, hw.cursor_number, hw.cursor_pos,
                             hw.disp_limits, blink.cursor_painted, false));
  blink.cursor_painted := not blink.cursor_painted;
end;
