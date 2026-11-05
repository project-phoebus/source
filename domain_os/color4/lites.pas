{ COLOR4_$LITES - draw the lights.

  Image addresses:
    sau7  0x3C48C020  COLOR4_$LITES
    sau8  0x03C8033C  COLOR4_$LITES

  - Sixteen lights, one per bit of pattern (bit 0 first), each a word of
    16 lines at its column of the line y_pos: a light's edge lines and
    sides are drawn by its bit, its inside cleared.
  - Under the unit's lights spin lock; nothing is drawn with flag 10 of
    the control word set.  The registers the drawing changes are put
    back.

  Status stored: none.
}

[section(color4_wired_proc, wired_data)]
procedure color4_$lites(dcte: color4_$dcte_ptr_t; pattern: integer;
                        y_pos: integer);
  options(val_param);
var
  columns: static array[0..color4_$lite_count - 1] of integer :=
    [16#22, 16#20, 16#1E, 16#1C, 16#19, 16#17, 16#15, 16#13,
     16#10, 16#0E, 16#0C, 16#0A, 16#07, 16#05, 16#03, 16#01];  { +0x00 }
  sides: static array[0..1] of pinteger := [16#8001, 16#7FFE];  { +0x20 }
  edges: static array[0..1] of pinteger := [16#FFFF, 16#0000];  { +0x24 }
  info: color4_$info_ptr_t;
  bytes_per_line: integer32;
  offset: integer32;
  token: pinteger;
  line: ^color4_$memory_line_t;
  saved_400: color4_$byte_t;
  flag_12: boolean;
  saved_404: color4_$byte_t;
  i: integer;
  row: integer;
begin
  info := dcte^.info;
  bytes_per_line := dcte^.hdm^.line_bits div 8;
  offset := y_pos * bytes_per_line;
  token := ml_$spin_lock(info^.lites_lock);
  with info^.regs^ do begin
    if ctl.flag_10 then begin
      ml_$spin_unlock(info^.lites_lock, token);
      return;
    end;
    saved_404 := reg_404;
    saved_400 := reg_400;
    reg_400 := 16#E0;
    flag_12 := ctl.flag_12;
    ctl.flag_12 := false;
    mask := 0;
    reg_404 := 16#C0;

    { the lights' 16 lines cleared }
    line := univ_ptr(offset + info^.memory);
    for row := 1 to color4_$lite_lines do begin
      for i := color4_$lite_count - 1 downto 0 do
        line^[columns[i]] := 0;
      line := univ_ptr(integer32(line) + bytes_per_line);
    end;

    { the edges and sides, by the pattern's bits }
    reg_404 := 16#CA;
    line := univ_ptr(offset + info^.memory);
    for i := 0 to color4_$lite_count - 1 do
      line^[columns[i]] := edges[rshft(pattern, i) & 1];
    line := univ_ptr(integer32(line) + bytes_per_line);
    for row := 1 to color4_$lite_lines - 2 do begin
      for i := 0 to color4_$lite_count - 1 do
        line^[columns[i]] := sides[rshft(pattern, i) & 1];
      line := univ_ptr(integer32(line) + bytes_per_line);
    end;
    for i := 0 to color4_$lite_count - 1 do
      line^[columns[i]] := edges[rshft(pattern, i) & 1];

    reg_404 := saved_404;
    reg_400 := saved_400;
    ctl.flag_12 := flag_12;
  end;
  ml_$spin_unlock(info^.lites_lock, token);
end;
