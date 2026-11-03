{ COLOR_$INT_INIT - set the color board's interrupt registers.

  Image addresses:
    sau4  0x0F87B0E0  COLOR_$INT_INIT
    sau5  0x00E72CF8  COLOR_$INT_INIT

  - The interrupt vector is the board's "instruction queue done" (16#A8,
    COLOR_$INT_DECODE's; with `color_board_iomap' 16#CE).

  Status stored: none.
}

procedure color_$int_init;
begin
  with color_sup do begin
    int_ctl := [];
    vector := color_int_vector;
  end;
end;
