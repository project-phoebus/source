{ COLOR7_$CLEAR_SCREEN - clear the screen.

  Image addresses:
    sau7  0x3C4846DE  COLOR7_$CLEAR_SCREEN

  - The display TTY's form feed (DTTY_$PUTC); the descriptor is not
    read.

  Status stored: none.
}

procedure color7_$clear_screen(dcte: color7_$dcte_ptr_t);
  options(val_param);
begin
  dtty_$putc(chr(12));
end;
