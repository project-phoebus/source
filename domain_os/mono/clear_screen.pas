{ MONO_$CLEAR_SCREEN - clear the screen.

  Image addresses:
    sau8  0x03C79C10  MONO_$CLEAR_SCREEN

  - Does nothing: the descriptor is not read.

  Status stored: none.
}

procedure mono_$clear_screen(dcte: mono_$dcte_ptr_t);
  options(val_param);
begin
end;
