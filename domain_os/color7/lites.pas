{ COLOR7_$LITES - draw the lights.

  Image addresses:
    sau7  0x3C48D28C  COLOR7_$LITES

  - Under COLOR7_STATIC's spin lock, and only while the drawing engine
    is idle; the engine's settings are saved and given back after.
  - The 16 lights are columns of 16 lines from word 3 of line y_pos,
    light 15 first; a light whose bit of pattern is set is filled, the
    others are their frame.  On configuration 13 the columns are cleared
    first.

  Status stored: none.
}

[section(color7_wired_proc, wired_data)]
procedure color7_$lites(dcte: color7_$dcte_ptr_t; pattern: integer;
                        y_pos: integer);
  options(val_param);
var
  s_0e8: integer32;
  s_0ec: integer32;
  s_0e0: integer32;
  s_0e4: integer32;
  s_114: integer32;
  s_104: integer32;
  s_148: integer32;
  s_150: integer32;
  s_3060: integer32;
  s_3068: integer32;
  s_3064: integer32;
  s_3050: integer32;
  s_304c: integer32;
  s_3048: integer32;
  s_3044: integer32;
  s_3040: integer32;
  s_306c: integer32;
  s_3070: integer32;
  s_216c: integer32;
  s_2164: integer32;
  st: color7_$status_t;
  base: integer32;
  column: integer32;
  p: integer32;
  token: pinteger;
  fill: integer;
  bit: integer;
  i: integer;
  j: integer;
begin
  token := ml_$spin_lock(color7_static.lock);
  st := color7_$status_reg_ptr_t(integer32(color7_static.regs) +
                                 color7_$status_offset)^.status;
  if st.busy = 0 then begin
    with color7_static.regs^ do begin
      { Save the engine's settings, and set the full screen. }
      s_2164 := reg_2164;
      s_216c := reg_216c;
      s_3070 := reg_3070;
      s_306c := reg_306c;
      s_3040 := reg_3040;
      s_3044 := reg_3044;
      s_3048 := reg_3048;
      s_304c := reg_304c;
      s_3050 := reg_3050;
      s_3064 := reg_3064;
      s_3068 := reg_3068;
      s_3060 := reg_3060;
      s_150 := reg_150;
      s_148 := reg_148;
      s_104 := reg_104;
      s_114 := reg_114;
      s_0e4 := reg_0e4;
      s_0e0 := reg_0e0;
      s_0ec := reg_0ec;
      s_0e8 := reg_0e8;
      reg_216c := color7_$op_216c;
      reg_3070 := color7_$op_3070;
      reg_306c := 0;
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
      base := y_pos * 256 * 2 + (color7_$memory_va + color7_$lite_offset);

      { On configuration 13, clear the columns. }
      if color7_static.config_13 then begin
        reg_2164 := color7_$op_fill;
        column := base;
        bit := color7_$lite_count - 1;
        for i := 1 to color7_$lite_count do begin
          p := column;
          for j := 1 to color7_$lite_lines do begin
            color7_$word_ptr_t(p)^ := 0;
            p := p + color7_$line_bytes;
          end;
          if bit mod 4 = 0 then
            column := column + 8
          else
            column := column + 4;
          bit := bit - 1;
        end;
        color7_wait_idle;
      end;
    end;

    { Draw the lights. }
    with color7_static.regs^ do begin
      reg_2164 := color7_$op_copy;
      reg_3040 := 5;
      reg_3044 := 5;
      reg_3048 := 0;
      reg_304c := 0;
    end;
    column := base;
    bit := color7_$lite_count - 1;
    for i := 1 to color7_$lite_count do begin
      color7_$word_ptr_t(column)^ := color7_$lite_on;
      if (lshft(1, bit) & pattern) <> 0 then
        fill := color7_$lite_on
      else
        fill := color7_$lite_off;
      p := column + color7_$line_bytes;
      for j := 2 to color7_$lite_lines - 1 do begin
        color7_$word_ptr_t(p)^ := fill;
        p := p + color7_$line_bytes;
      end;
      color7_$word_ptr_t(p)^ := color7_$lite_on;
      if bit mod 4 = 0 then
        column := column + 8
      else
        column := column + 4;
      bit := bit - 1;
    end;

    { Give the engine its settings back. }
    with color7_static.regs^ do begin
      reg_2164 := s_2164;
      reg_216c := s_216c;
      reg_3070 := s_3070;
      reg_306c := s_306c;
      reg_3040 := s_3040;
      reg_3044 := s_3044;
      reg_3048 := s_3048;
      reg_304c := s_304c;
      reg_3050 := s_3050;
      reg_3064 := s_3064;
      reg_3068 := s_3068;
      reg_3060 := s_3060;
      reg_150 := s_150;
      reg_148 := s_148;
      reg_104 := s_104;
      reg_114 := s_114;
      reg_0e4 := s_0e4;
      reg_0e0 := s_0e0;
      reg_0ec := s_0ec;
      reg_0e8 := s_0e8;
    end;
  end;
  ml_$spin_unlock(color7_static.lock, token);
end;
