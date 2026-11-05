{ COLOR7_$DISPLAY_LOGO - copy the boot logo into display memory.

  Image addresses:
    sau7  0x3C4847C4  COLOR7_$DISPLAY_LOGO

  - The logo's place is word 24 of a line from the screen's origin
    register, by the configuration.  Once the drawing engine is idle it
    gets the full-screen settings; on configuration 13 the logo's area
    is cleared first.  Then the logo is copied, and the engine left with
    its idle operation.

  Status stored:
    status_$ok: always
}

procedure color7_$display_logo(dcte: color7_$dcte_ptr_t;
                               logo: smd_logo_ptr_t;
                               out status: status_$t);
  options(val_param);
var
  origin: integer32;
  line: integer;
  base: color7_$lines_ptr_t;
  row: integer;
  col: integer;
begin
  status.all := status_$ok;
  if color7_static.config_12 then
    origin := color7_static.regs^.reg_1e8 - color7_$logo_line_config_12
  else
    origin := color7_static.regs^.reg_1e8 - color7_$logo_line_other;
  line := (origin + color7_$logo_line_add) mod color7_$memory_lines;
  base := color7_$lines_ptr_t((line * 256 + color7_$logo_word) * 2 +
                              color7_$memory_va);
  color7_wait_idle;
  with color7_static.regs^ do begin
    reg_216c := color7_$op_216c;
    reg_3070 := color7_$op_3070;
    reg_306c := 0;
    reg_3048 := 0;
    reg_304c := 0;
    reg_3050 := 0;
    reg_3064 := color7_$plane_all;
    reg_3068 := color7_$plane_all;
    reg_3060 := color7_$plane_all;
    reg_150 := -1;
    reg_148 := 0;
    reg_104 := 0;
    reg_114 := 0;
    reg_0e4 := 0;
    reg_0e0 := color7_$x_max;
    reg_0ec := 0;
    reg_0e8 := color7_$y_max;

    { On configuration 13, clear the logo's area. }
    if color7_static.config_13 then begin
      reg_2164 := color7_$op_fill;
      reg_3040 := color7_$plane_all;
      reg_3044 := color7_$plane_all;
      for row := 1 to color7_$logo_rows do
        for col := 1 to color7_$logo_longs do
          base^[row].longs[col] := 0;
      color7_wait_idle;
    end;
  end;

  { Copy the logo. }
  with color7_static.regs^ do begin
    reg_2164 := color7_$op_copy;
    reg_3040 := 1;
    reg_3044 := 1;
  end;
  for row := 1 to color7_$logo_rows do
    for col := 1 to color7_$logo_words do
      base^[row].words[col] := logo^[row, col];
  color7_wait_idle;
  with color7_static.regs^ do begin
    reg_2164 := color7_$op_idle;
    reg_3040 := color7_$plane_all;
    reg_3044 := color7_$plane_all;
  end;
end;
