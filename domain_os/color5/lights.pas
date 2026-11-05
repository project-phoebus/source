{ COLOR5_$LIGHTS - draw the lights.

  Image addresses:
    sau7  0x3C48C780  COLOR5_$LIGHTS
    sau8  0x03C80A9C  COLOR5_$LIGHTS

  - Sixteen lights, one per bit of pattern (bit 15 first), each a word
    of 16 lines at its column of the line y_pos: a light's edge lines
    are all set and its sides drawn when its bit is set, its edge lines
    clear and its inside drawn when not, after the 16 lines are cleared.
  - Under the unit's lights spin lock; nothing is drawn with flag 10 of
    the control word set.  The registers the drawing changes are put
    back.

  Status stored: none.
}

[section(color5_wired_proc, wired_data)]
procedure color5_$lights(dcte: color5_$dcte_ptr_t; pattern: integer;
                         y_pos: integer);
  options(val_param);
var
  columns: static array[0..color5_$light_count - 1] of integer :=
    [16#25, 16#23, 16#21, 16#1F, 16#1B, 16#19, 16#17, 16#15,
     16#11, 16#0F, 16#0D, 16#0B, 16#07, 16#03, 16#05, 16#01];  { +0x00 }
  info: color5_$info_ptr_t;
  bytes_per_line: integer32;
  offset: integer32;
  token: pinteger;
  line: ^color5_$memory_line_t;
  saved_404: color5_$byte_t;
  saved_400: color5_$byte_t;
  flag_12: boolean;
  saved_405: color5_$byte_t;
  i: integer;
  row: integer;
begin
  info := dcte^.info;
  bytes_per_line := dcte^.hdm^.line_bits div 8;
  offset := y_pos * bytes_per_line;
  token := ml_$spin_lock(info^.lights_lock);
  with info^.regs^ do begin
    if ctl.flag_10 then begin
      ml_$spin_unlock(info^.lights_lock, token);
      return;
    end;
    saved_405 := reg_405;
    saved_404 := reg_404;
    saved_400 := reg_400;
    reg_405 := 16#C0;
    reg_400 := 16#E0;
    flag_12 := ctl.flag_12;
    ctl.flag_12 := false;
    mask := 0;
    reg_404 := 0;

    { the lights' 16 lines cleared }
    line := univ_ptr(offset + info^.memory);
    for row := 1 to color5_$light_lines do begin
      for i := color5_$light_count - 1 downto 0 do
        line^[columns[i]] := 0;
      line := univ_ptr(integer32(line) + bytes_per_line);
    end;

    { the edges and sides, by the pattern's bits }
    reg_404 := 16#FA;
    line := univ_ptr(offset + info^.memory);
    for i := color5_$light_count - 1 downto 0 do
      if (lshft(1, i) & pattern) = 0 then
        line^[columns[i]] := 0
      else
        line^[columns[i]] := 16#FFFF;
    line := univ_ptr(integer32(line) + bytes_per_line);
    for row := 1 to color5_$light_lines - 2 do begin
      for i := color5_$light_count - 1 downto 0 do
        if (lshft(1, i) & pattern) = 0 then
          line^[columns[i]] := 16#7FFE
        else
          line^[columns[i]] := 16#8001;
      line := univ_ptr(integer32(line) + bytes_per_line);
    end;
    for i := color5_$light_count - 1 downto 0 do
      if (lshft(1, i) & pattern) = 0 then
        line^[columns[i]] := 0
      else
        line^[columns[i]] := 16#FFFF;

    reg_405 := saved_405;
    reg_404 := saved_404;
    reg_400 := saved_400;
    ctl.flag_12 := flag_12;
  end;
  ml_$spin_unlock(info^.lights_lock, token);
end;
