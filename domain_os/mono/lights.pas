{ MONO_$LIGHTS - draw the lights.

  Image addresses:
    sau8  0x03C8110C  MONO_$LIGHTS

  - Sixteen lights, one per bit of pattern (bit 0 first), each a word of
    16 lines at its column of the line y_pos: a light's edge lines are
    all set and its sides drawn when its bit is clear, its edge lines
    clear and its inside drawn when set; the pattern is inverted first
    when flag 15 of the control word is clear.
  - A line beyond the display memory's first 64 KB is reached with flag
    14 set.
  - Under the unit's lights spin lock; nothing is drawn with flag 10 of
    the control word set.  The registers the drawing changes are put
    back.

  Status stored: none.
}

[section(mono_wired_proc, wired_data)]
procedure mono_$lights(dcte: mono_$dcte_ptr_t; pattern: integer;
                       y_pos: integer);
  options(val_param);
var
  columns: static array[0..mono_$light_count - 1] of integer :=
    [16#25, 16#23, 16#21, 16#1F, 16#1B, 16#19, 16#17, 16#15,
     16#11, 16#0F, 16#0D, 16#0B, 16#07, 16#03, 16#05, 16#01];  { +0x00 }
  info: mono_$info_ptr_t;
  bytes_per_line: integer32;
  offset: integer32;
  line: mono_$line_ptr_t;
  token: pinteger;
  flag_14: boolean;
  saved_404: mono_$reg_404_t;
  saved_400: mono_$byte_t;
  flag_12: boolean;
  high: integer32;
  i: integer;
  row: integer;
begin
  info := dcte^.info;
  bytes_per_line := dcte^.hdm^.line_bits div 8;
  offset := y_pos * bytes_per_line;
  line := univ_ptr(offset + info^.memory);
  token := ml_$spin_lock(info^.lights_lock);
  with info^.regs^ do begin
    if ctl.flag_10 then begin
      ml_$spin_unlock(info^.lights_lock, token);
      return;
    end;
    high := offset & 16#FFFF0000;
    if high <> 0 then begin
      flag_14 := ctl.flag_14;
      ctl.flag_14 := true;
    end;
    saved_404 := reg_404;
    reg_404.all := 16#C0;
    saved_400 := reg_400;
    reg_400 := 16#E0;
    flag_12 := ctl.flag_12;
    ctl.flag_12 := false;
    mask := 0;
    if not ctl.flag_15 then
      pattern := ~pattern;

    { the edges and sides, by the pattern's bits }
    for i := 0 to mono_$light_count - 1 do
      if (lshft(1, i) & pattern) = 0 then
        line^[columns[i]] := 16#FFFF
      else
        line^[columns[i]] := 0;
    line := univ_ptr(integer32(line) + bytes_per_line);
    for row := 1 to mono_$light_lines - 2 do begin
      for i := 0 to mono_$light_count - 1 do
        if (lshft(1, i) & pattern) = 0 then
          line^[columns[i]] := 16#8001
        else
          line^[columns[i]] := 16#7FFE;
      line := univ_ptr(integer32(line) + bytes_per_line);
    end;
    for i := 0 to mono_$light_count - 1 do
      if (lshft(1, i) & pattern) = 0 then
        line^[columns[i]] := 16#FFFF
      else
        line^[columns[i]] := 0;

    reg_404 := saved_404;
    reg_400 := saved_400;
    ctl.flag_12 := flag_12;
    if high <> 0 then
      ctl.flag_14 := flag_14;
  end;
  ml_$spin_unlock(info^.lights_lock, token);
end;
