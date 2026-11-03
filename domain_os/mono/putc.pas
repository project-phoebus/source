{ MONO_$PUTC - write characters to the display TTY.

  Image addresses:
    sau8  0x03C810D6  MONO_$PUTC

  - count characters, one at a time (DTTY_$PUTC); the descriptor is not
    read.

  Status stored: none.
}

[section(mono_wired_proc, wired_data)]
procedure mono_$putc(dcte: mono_$dcte_ptr_t; in chars: mono_$chars_t;
                       count: integer);
  options(val_param);
var
  i: integer;
begin
  for i := 1 to count do
    dtty_$putc(chars[i]);
end;
