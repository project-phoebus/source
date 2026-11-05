{ COLOR7_$PUTC - write characters to the display TTY.

  Image addresses:
    sau7  0x3C484788  COLOR7_$PUTC

  - count characters, one at a time (DTTY_$PUTC); the descriptor is not
    read.

  Status stored: none.
}

procedure color7_$putc(dcte: color7_$dcte_ptr_t; in chars: color7_$chars_t;
                       count: integer);
  options(val_param);
var
  i: integer;
begin
  for i := 1 to count do
    dtty_$putc(chars[i]);
end;
