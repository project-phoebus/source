{ COLOR7_$XOR_CURSOR - draw or remove the cursor.

  Image addresses:
    sau7  0x3C48CF06  COLOR7_$XOR_CURSOR

  - Under the SMD request lock (PROC1_$SET_LOCK), through the cursor
    port.
  - To remove it, the cursor is turned off.  Otherwise a pattern other
    than the board's is loaded first (SMD_$CURSOR_TABLE's, each word as
    two bytes with zeros after); then the position, the pattern's hot
    spot kept inside limits, is set with the configuration's offsets and
    the cursor turned on.
  - The result is always true.

  Status stored: none.
}

[section(color7_wired_proc, wired_data)]
function color7_$xor_cursor(dcte: color7_$dcte_ptr_t; cursor_num: pinteger;
                            pos: smd_$pos_t;
                            in limits: smd_$window_limits_t;
                            remove: boolean): boolean;
  options(val_param);
var
  x_reg: integer32;
  y_reg: integer32;
  bits: integer32;
  x: integer;
  y: integer;
  row: integer;
  i: integer;
begin
  proc1_$set_lock(ml_$smd_request_lock);
  if remove then begin
    color7_write_reg(color7_$port_cursor, color7_$port_data_4, 0);
    color7_write_reg(color7_$port_cursor, color7_$port_addr, 0);
    color7_write_reg(color7_$port_cursor, color7_$port_data_c,
                     color7_$cursor_cmd_off);
  end
  else begin
    { Load the pattern when the board has another. }
    if cursor_num <> color7_static.cursor then begin
      color7_static.cursor := cursor_num;
      color7_write_reg(color7_$port_cursor, color7_$port_data_4, 0);
      color7_write_reg(color7_$port_cursor, color7_$port_addr, 0);
      with smd_$cursor_table[cursor_num] do
        for row := 1 to color7_$cursor_rows do begin
          bits := bitmap[row];
          color7_write_reg(color7_$port_cursor, color7_$port_data_8,
                           rshft(bits, 8) & 255);
          color7_write_reg(color7_$port_cursor, color7_$port_data_8,
                           bits & 255);
          for i := 1 to color7_$cursor_row_pad do
            color7_write_reg(color7_$port_cursor, color7_$port_data_8, 0);
        end;
      for i := 1 to color7_$cursor_pad do
        color7_write_reg(color7_$port_cursor, color7_$port_data_8, 0);
    end;

    { The position, kept inside the limits. }
    with smd_$cursor_table[cursor_num] do begin
      x := pos.column - hot_x;
      if x < limits.xs then
        x := limits.xs;
      if limits.xe - width + 1 < x then
        x := limits.xe - width + 1;
      x := x + color7_$cursor_margin;
      y := pos.line + hot_y_adj - height + 1;
      if y < limits.ys then
        y := limits.ys;
      if limits.ye - height + 1 < y then
        y := limits.ye - height + 1;
      y := y + color7_$cursor_margin;
    end;
    if color7_static.config_13 then
      x_reg := x + color7_$cursor_x_config_13
    else
      x_reg := x + color7_$cursor_x_other;
    if color7_static.config_12 then
      y_reg := y + color7_$cursor_y_config_12
    else
      y_reg := y + color7_$cursor_y_other;

    { Set it, and turn the cursor on. }
    color7_write_reg(color7_$port_cursor, color7_$port_data_4, 0);
    color7_write_reg(color7_$port_cursor, color7_$port_addr, 1);
    color7_write_reg(color7_$port_cursor, color7_$port_data_c,
                     x_reg & 255);
    color7_write_reg(color7_$port_cursor, color7_$port_addr, 2);
    color7_write_reg(color7_$port_cursor, color7_$port_data_c,
                     rshft(x_reg, 8) & 15);
    color7_write_reg(color7_$port_cursor, color7_$port_addr, 3);
    color7_write_reg(color7_$port_cursor, color7_$port_data_c,
                     y_reg & 255);
    color7_write_reg(color7_$port_cursor, color7_$port_addr, 4);
    color7_write_reg(color7_$port_cursor, color7_$port_data_c,
                     rshft(y_reg, 8) & 15);
    color7_write_reg(color7_$port_cursor, color7_$port_data_4, 0);
    color7_write_reg(color7_$port_cursor, color7_$port_addr, 0);
    color7_write_reg(color7_$port_cursor, color7_$port_data_c,
                     color7_$cursor_cmd_on);
  end;
  proc1_$clr_lock(ml_$smd_request_lock);
  color7_$xor_cursor := true;
end;
