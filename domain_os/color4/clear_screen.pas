{ COLOR4_$CLEAR_SCREEN - clear the screen.

  Image addresses:
    sau7  0x3C483CE8  COLOR4_$CLEAR_SCREEN
    sau8  0x03C79594  COLOR4_$CLEAR_SCREEN

  - Does nothing: the descriptor is not read.

  Status stored: none.
}

procedure color4_$clear_screen(dcte: color4_$dcte_ptr_t);
  options(val_param);
begin
end;
