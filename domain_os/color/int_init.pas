{ COLOR_$INT_INIT - set the color board's interrupt registers.

  Image addresses:
    sau5  0x00E72CF8  COLOR_$INT_INIT

  - The interrupt vector is 16#A8, COLOR_$INT_DECODE's "instruction
    queue done".

  Status stored: none.
}

procedure color_$int_init;
begin
  with color_sup do begin
    int_ctl := [];
    vector := 16#A8;
  end;
end;
