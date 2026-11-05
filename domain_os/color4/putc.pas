{ COLOR4_$PUTC - write characters to the display TTY.

  Image addresses:
    sau7  0x3C48BFEA  COLOR4_$PUTC
    sau8  0x03C80306  COLOR4_$PUTC

  - count characters, one at a time (DTTY_$PUTC); the descriptor is not
    read.

  Status stored: none.
}

[section(color4_wired_proc, wired_data)]
procedure color4_$putc(dcte: color4_$dcte_ptr_t; in chars: color4_$chars_t;
                       count: integer);
  options(val_param);
var
  i: integer;
begin
  for i := 1 to count do
    dtty_$putc(chars[i]);
end;
