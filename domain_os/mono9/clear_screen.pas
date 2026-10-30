{ MONO9_$CLEAR_SCREEN - clear the screen.

  Image addresses:
    sau9  0x3C476E00  MONO9_$CLEAR_SCREEN

  - A form feed to the display TTY (DTTY_$PUTC); the descriptor is not
    read.

  Status stored: none.
}

procedure mono9_$clear_screen(dcte: mono9_$dcte_ptr_t);
  options(val_param);
begin
  dtty_$putc(chr(12));                    { form feed }
end;
