{ COLOR5_$CLEAR_SCREEN - clear the screen.

  Image addresses:
    sau7  0x3C484024  COLOR5_$CLEAR_SCREEN
    sau8  0x03C798D0  COLOR5_$CLEAR_SCREEN

  - Does nothing: the descriptor is not read.

  Status stored: none.
}

procedure color5_$clear_screen(dcte: color5_$dcte_ptr_t);
  options(val_param);
begin
end;
