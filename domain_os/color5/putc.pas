{ COLOR5_$PUTC - write characters to the display TTY.

  Image addresses:
    sau8  0x03C80A66  COLOR5_$PUTC

  - count characters, one at a time (DTTY_$PUTC); the descriptor is not
    read.

  Status stored: none.
}

[section(color5_wired_proc, wired_data)]
procedure color5_$putc(dcte: color5_$dcte_ptr_t; in chars: color5_$chars_t;
                       count: integer);
  options(val_param);
var
  i: integer;
begin
  for i := 1 to count do
    dtty_$putc(chars[i]);
end;
