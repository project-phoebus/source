{ MONO9_$BLINK_CURSOR - blink the cursor once.

  Image addresses:
    sau9  0x3C4203AA  MONO9_$BLINK_CURSOR

  - The cursor is exclusive-or'ed into the display memory at its
    position (MONO9_$XOR_CURSOR) and the blink state toggled.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure mono9_$blink_cursor(dcte: mono9_$dcte_ptr_t;
                              var blink: mono9_$blink_t;
                              var cursor: mono9_$cursor_t);
  options(val_param);
var
  info: mono9_$info_ptr_t;
begin
  info := dcte^.info;
  mono9_$xor_cursor(info, cursor.cursor_num, cursor.pos);
  blink.on := not blink.on;
end;
