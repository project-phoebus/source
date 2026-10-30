{ SMD_$NOP1 - the default for a device routine that takes only its descriptor.

  Image addresses:
    sau9  0x3C474370  SMD_$NOP1

  - The default of the vector's shutdown, cold_init and clear_screen
    routines: nothing.

  Status stored: none.
}

procedure smd_$nop1(dcte: univ_ptr);
  options(val_param);
begin
end;
