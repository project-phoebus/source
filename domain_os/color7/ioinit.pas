{ COLOR7_$IOINIT - find and set up the COLOR7 board at boot.

  Image addresses:
    sau7  0x3C43F084  COLOR7_$IOINIT

  - No board unless ROADRUNNER is set or PEB_$INFO's flag at 0x1D is
    clear, and the identification ROM answers (TESTPAGE) with `COYO'.
  - The board is reset and its configuration noted (COLOR7_STATIC's
    config_13 and config_12, the control register's bits 13 and 12 once
    it reads other than all ones); the drawing engine gets the
    full-screen settings, the timing port the configuration's tables,
    the cursor and the other ports their setup, and on configuration 13
    the three color maps a ramp.
  - Then the video is turned on and the device added to the display
    driver (SMD_$ADD_DEVICE).

  Status stored (the result):
    status_$ok: the board is there
    status_$io_controller_not_in_system: no board
}

[section(os_init_proc, os_init_data)]
function color7_$ioinit(var dcte: color7_$dcte_t): integer32;
label
  done;
var
  timing_13: static array[1..4] of color7_$port_set_t := [    { +0x000 }
    [16#98, 4], [16#99, 4], [16#9A, 0], [16#9B, 0]];
  timing_other: static array[1..4] of color7_$port_set_t := [ { +0x020 }
    [16#98, 0], [16#99, 0], [16#9A, 0], [16#9B, 0]];
  setup_12: static array[1..42] of color7_$port_set_t := [    { +0x040 }
    [16#9C, 16#20], [16#80, 16#1F], [16#81, 16#1F], [16#82, 16#2D],
    [16#83, 1], [16#84, 16#25], [16#85, 0], [16#86, 0], [16#87, 0],
    [16#88, 16#25], [16#89, 8], [16#8A, 16#FF], [16#8B, 0], [16#8C, 0],
    [16#8D, 0], [16#8E, 0], [16#8F, 0], [16#90, 5], [16#91, 2],
    [16#92, 2], [16#93, 16#29], [16#94, 16#FF], [16#95, 3], [16#96, 0],
    [16#97, 16#10], [16#9F, 0], [16#A0, 16#80], [16#A1, 16#F],
    [16#A2, 0], [16#A3, 0], [16#A4, 0], [16#A5, 16#FF], [16#A6, 16#10],
    [16#A7, 16#FF], [16#A8, 16#5E], [16#A9, 16#C8], [16#AA, 16#5F],
    [16#AB, 16#A8], [16#AC, 16#5E], [16#AD, 16#C8], [16#AE, 16#5D],
    [16#AF, 16#94]];
  setup_other: static array[1..42] of color7_$port_set_t := [ { +0x190 }
    [16#9C, 16#20], [16#80, 16#26], [16#81, 16#26], [16#82, 16#2C],
    [16#83, 1], [16#84, 16#25], [16#85, 0], [16#86, 0], [16#87, 0],
    [16#88, 16#25], [16#89, 16#E], [16#8A, 16#FF], [16#8B, 0],
    [16#8C, 0], [16#8D, 0], [16#8E, 0], [16#8F, 0], [16#90, 5],
    [16#91, 2], [16#92, 2], [16#93, 16#31], [16#94, 16#FF], [16#95, 3],
    [16#96, 0], [16#97, 16#10], [16#9F, 0], [16#A0, 16#80],
    [16#A1, 16#F], [16#A2, 0], [16#A3, 0], [16#A4, 0], [16#A5, 16#FF],
    [16#A6, 16#10], [16#A7, 16#FF], [16#A8, 16#5E], [16#A9, 16#C8],
    [16#AA, 16#5F], [16#AB, 16#A8], [16#AC, 16#5E], [16#AD, 16#C8],
    [16#AE, 16#5D], [16#AF, 16#94]];
  i: integer;
  ctl: color7_$ctl_t;
  id: color7_$id_t;
  status: status_$t;
begin
  status.all := status_$io_controller_not_in_system;
  if not roadrunner and peb_$info.flag_1d then
    goto done;
  if not testpage(1, addr(color7_$rom_ptr_t(integer32(color7_static.regs) +
                                           color7_$rom_offset)^.id[1]),
                  id.w[1]) then
    goto done;
  if not testpage(1, addr(color7_$rom_ptr_t(integer32(color7_static.regs) +
                                           color7_$rom_offset)^.id[2]),
                  id.w[2]) then
    goto done;
  if id.l <> color7_$board_id then
    goto done;
  status.all := status_$ok;

  { Reset the board and wait for its control register. }
  color7_$ctl_reg_ptr_t(integer32(color7_static.regs) +
                        color7_$ctl_offset)^.ctl.all := color7_$ctl_init_1;
  color7_$ctl_reg_ptr_t(integer32(color7_static.regs) +
                        color7_$ctl_offset)^.ctl.all := color7_$ctl_init_2;
  color7_$ctl_reg_ptr_t(integer32(color7_static.regs) +
                        color7_$ctl_offset)^.ctl.all :=
    color7_$ctl_reg_ptr_t(integer32(color7_static.regs) +
                          color7_$ctl_offset)^.ctl.all &
    color7_$ctl_reset_mask;
  color7_wait_idle;
  with color7_static do begin
    for i := 1 to color7_$ready_polls do
      if color7_$ctl_reg_ptr_t(integer32(regs) +
                               color7_$ctl_offset)^.ctl.all <>
         color7_$ctl_not_ready then
        exit;
    ctl := color7_$ctl_reg_ptr_t(integer32(regs) + color7_$ctl_offset)^.ctl;
    config_13 := color7_$ctl_config_13 in ctl.bits;
    config_12 := color7_$ctl_config_12 in ctl.bits;

    { The drawing engine's settings. }
    with regs^ do begin
      reg_2164 := color7_$op_idle;
      reg_216c := color7_$op_216c;
      reg_3070 := color7_$op_3070;
      reg_306c := 0;
      reg_1e0 := 1856;
      reg_21ec := 0;
      reg_1f0 := 0;
      reg_3040 := color7_$plane_all;
      reg_3044 := color7_$plane_all;
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
      reg_21a4 := 0;
      reg_21ac := 0;
    end;

    { The timing port's tables for the configuration. }
    if config_12 then
      for i := 1 to 42 do begin
        color7_write_reg(color7_$port_timing, color7_$port_addr,
                         setup_12[i].addr);
        color7_write_reg(color7_$port_timing, color7_$port_data_4,
                         setup_12[i].value);
      end
    else
      for i := 1 to 42 do begin
        color7_write_reg(color7_$port_timing, color7_$port_addr,
                         setup_other[i].addr);
        color7_write_reg(color7_$port_timing, color7_$port_data_4,
                         setup_other[i].value);
      end;
  end;
  if color7_static.config_13 then
    for i := 1 to 4 do begin
      color7_write_reg(color7_$port_timing, color7_$port_addr,
                       timing_13[i].addr);
      color7_write_reg(color7_$port_timing, color7_$port_data_4,
                       timing_13[i].value);
    end
  else
    for i := 1 to 4 do begin
      color7_write_reg(color7_$port_timing, color7_$port_addr,
                       timing_other[i].addr);
      color7_write_reg(color7_$port_timing, color7_$port_data_4,
                       timing_other[i].value);
    end;

  { The cursor port: no cursor loaded. }
  color7_static.cursor := -1;
  color7_write_reg(color7_$port_cursor, color7_$port_data_4, 0);
  color7_write_reg(color7_$port_cursor, color7_$port_addr, 0);
  color7_write_reg(color7_$port_cursor, color7_$port_data_c,
                   color7_$cursor_cmd_off);
  color7_write_reg(color7_$port_cursor, color7_$port_data_4, 0);
  color7_write_reg(color7_$port_cursor, color7_$port_addr, 0);
  for i := 1 to color7_$cursor_clear do
    color7_write_reg(color7_$port_cursor, color7_$port_data_8, 0);

  { The other ports' setup for the configuration. }
  if color7_static.config_13 then begin
    color7_write_reg(color7_$port_10, color7_$port_addr, 4);
    color7_write_reg(color7_$port_10, color7_$port_data_8, 16#FF);
    color7_write_reg(color7_$port_10, color7_$port_addr, 5);
    color7_write_reg(color7_$port_10, color7_$port_data_8, 0);
    color7_write_reg(color7_$port_10, color7_$port_addr, 6);
    color7_write_reg(color7_$port_10, color7_$port_data_8, 16#C3);
    color7_write_reg(color7_$port_10, color7_$port_addr, 7);
    color7_write_reg(color7_$port_10, color7_$port_data_8, 0);
    color7_write_reg(color7_$port_10, color7_$port_addr, 0);
    color7_write_reg(color7_$port_10, color7_$port_data_4, 0);
    color7_write_reg(color7_$port_10, color7_$port_addr, 1);
    color7_write_reg(color7_$port_10, color7_$port_data_4, 16#FF);
    color7_write_reg(color7_$port_10, color7_$port_addr, 5);
    color7_write_reg(color7_$port_10, color7_$port_data_4, 16#FF);
    color7_write_reg(color7_$port_10, color7_$port_addr, 0);
    color7_write_reg(color7_$port_10, color7_$port_data_c, 0);
    color7_write_reg(color7_$port_10, color7_$port_addr, 1);
    color7_write_reg(color7_$port_10, color7_$port_data_c, 16#FF);
    color7_write_reg(color7_$port_10, color7_$port_addr, 2);
    color7_write_reg(color7_$port_10, color7_$port_data_c, 16#FF);
    color7_write_reg(color7_$port_10, color7_$port_addr, 3);
    color7_write_reg(color7_$port_10, color7_$port_data_c, 16#FF);
    color7_write_reg(color7_$port_20, color7_$port_addr, 4);
    color7_write_reg(color7_$port_20, color7_$port_data_8, 16#FF);
    color7_write_reg(color7_$port_20, color7_$port_addr, 5);
    color7_write_reg(color7_$port_20, color7_$port_data_8, 0);
    color7_write_reg(color7_$port_20, color7_$port_addr, 6);
    color7_write_reg(color7_$port_20, color7_$port_data_8, 16#C3);
    color7_write_reg(color7_$port_20, color7_$port_addr, 7);
    color7_write_reg(color7_$port_20, color7_$port_data_8, 0);
    color7_write_reg(color7_$port_20, color7_$port_addr, 0);
    color7_write_reg(color7_$port_20, color7_$port_data_4, 0);
    color7_write_reg(color7_$port_20, color7_$port_addr, 1);
    color7_write_reg(color7_$port_20, color7_$port_data_4, 16#FF);
    color7_write_reg(color7_$port_20, color7_$port_addr, 5);
    color7_write_reg(color7_$port_20, color7_$port_data_4, 16#FF);
    color7_write_reg(color7_$port_20, color7_$port_addr, 0);
    color7_write_reg(color7_$port_20, color7_$port_data_c, 0);
    color7_write_reg(color7_$port_20, color7_$port_addr, 1);
    color7_write_reg(color7_$port_20, color7_$port_data_c, 0);
    color7_write_reg(color7_$port_20, color7_$port_addr, 2);
    color7_write_reg(color7_$port_20, color7_$port_data_c, 0);
    color7_write_reg(color7_$port_20, color7_$port_addr, 3);
    color7_write_reg(color7_$port_20, color7_$port_data_c, 0);
    color7_write_reg(color7_$port_30, color7_$port_addr, 4);
    color7_write_reg(color7_$port_30, color7_$port_data_8, 16#FF);
    color7_write_reg(color7_$port_30, color7_$port_addr, 5);
    color7_write_reg(color7_$port_30, color7_$port_data_8, 0);
    color7_write_reg(color7_$port_30, color7_$port_addr, 6);
    color7_write_reg(color7_$port_30, color7_$port_data_8, 16#C3);
    color7_write_reg(color7_$port_30, color7_$port_addr, 7);
    color7_write_reg(color7_$port_30, color7_$port_data_8, 0);
    color7_write_reg(color7_$port_30, color7_$port_addr, 0);
    color7_write_reg(color7_$port_30, color7_$port_data_4, 0);
    color7_write_reg(color7_$port_30, color7_$port_addr, 1);
    color7_write_reg(color7_$port_30, color7_$port_data_4, 16#FF);
    color7_write_reg(color7_$port_30, color7_$port_addr, 5);
    color7_write_reg(color7_$port_30, color7_$port_data_4, 0);
    color7_write_reg(color7_$port_30, color7_$port_addr, 0);
    color7_write_reg(color7_$port_30, color7_$port_data_c, 0);
    color7_write_reg(color7_$port_30, color7_$port_addr, 1);
    color7_write_reg(color7_$port_30, color7_$port_data_c, 0);
    color7_write_reg(color7_$port_30, color7_$port_addr, 2);
    color7_write_reg(color7_$port_30, color7_$port_data_c, 0);
    color7_write_reg(color7_$port_30, color7_$port_addr, 3);
    color7_write_reg(color7_$port_30, color7_$port_data_c, 0);
  end
  else begin
    color7_write_reg(color7_$port_30, color7_$port_addr, 4);
    color7_write_reg(color7_$port_30, color7_$port_data_8, 16#FF);
    color7_write_reg(color7_$port_30, color7_$port_addr, 5);
    color7_write_reg(color7_$port_30, color7_$port_data_8, 0);
    color7_write_reg(color7_$port_30, color7_$port_addr, 6);
    color7_write_reg(color7_$port_30, color7_$port_data_8, 16#C2);
    color7_write_reg(color7_$port_30, color7_$port_addr, 7);
    color7_write_reg(color7_$port_30, color7_$port_data_8, 0);
    color7_write_reg(color7_$port_30, color7_$port_addr, 0);
    color7_write_reg(color7_$port_30, color7_$port_data_4, 0);
    color7_write_reg(color7_$port_30, color7_$port_data_4, 0);
    color7_write_reg(color7_$port_30, color7_$port_data_4, 0);
    color7_write_reg(color7_$port_30, color7_$port_data_4, 16#FF);
    color7_write_reg(color7_$port_30, color7_$port_data_4, 16#FF);
    color7_write_reg(color7_$port_30, color7_$port_data_4, 16#FF);
    color7_write_reg(color7_$port_30, color7_$port_addr, 5);
    color7_write_reg(color7_$port_30, color7_$port_data_4, 16#FF);
    color7_write_reg(color7_$port_30, color7_$port_data_4, 16#FF);
    color7_write_reg(color7_$port_30, color7_$port_data_4, 0);
    color7_write_reg(color7_$port_30, color7_$port_addr, 0);
    color7_write_reg(color7_$port_30, color7_$port_data_c, 0);
    color7_write_reg(color7_$port_30, color7_$port_data_c, 0);
    color7_write_reg(color7_$port_30, color7_$port_data_c, 0);
    color7_write_reg(color7_$port_30, color7_$port_data_c, 16#FF);
    color7_write_reg(color7_$port_30, color7_$port_data_c, 0);
    color7_write_reg(color7_$port_30, color7_$port_data_c, 0);
    color7_write_reg(color7_$port_30, color7_$port_data_c, 16#FF);
    color7_write_reg(color7_$port_30, color7_$port_data_c, 0);
    color7_write_reg(color7_$port_30, color7_$port_data_c, 0);
    color7_write_reg(color7_$port_30, color7_$port_data_c, 16#FF);
    color7_write_reg(color7_$port_30, color7_$port_data_c, 0);
    color7_write_reg(color7_$port_30, color7_$port_data_c, 0);
  end;

  { On configuration 13, a ramp in the three color maps. }
  if color7_static.config_13 then begin
    for i := 0 to color7_$ramp_entries - 1 do begin
      color7_write_reg(color7_$port_50, color7_$port_addr, i * 4);
      color7_write_reg(color7_$port_50, color7_$port_data_4, 16#80);
      color7_write_reg(color7_$port_50, color7_$port_addr, i * 4 + 1);
      color7_write_reg(color7_$port_50, color7_$port_data_4, 16#F0);
      color7_write_reg(color7_$port_50, color7_$port_addr, i * 4 + 2);
      color7_write_reg(color7_$port_50, color7_$port_data_4, 10);
      color7_write_reg(color7_$port_60, color7_$port_addr, i * 4);
      color7_write_reg(color7_$port_60, color7_$port_data_4, 16#80);
      color7_write_reg(color7_$port_60, color7_$port_addr, i * 4 + 1);
      color7_write_reg(color7_$port_60, color7_$port_data_4, 16#F0);
      color7_write_reg(color7_$port_60, color7_$port_addr, i * 4 + 2);
      color7_write_reg(color7_$port_60, color7_$port_data_4, 10);
      color7_write_reg(color7_$port_70, color7_$port_addr, i * 4);
      color7_write_reg(color7_$port_70, color7_$port_data_4, 16#80);
      color7_write_reg(color7_$port_70, color7_$port_addr, i * 4 + 1);
      color7_write_reg(color7_$port_70, color7_$port_data_4, 16#F0);
      color7_write_reg(color7_$port_70, color7_$port_addr, i * 4 + 2);
      color7_write_reg(color7_$port_70, color7_$port_data_4, 10);
    end;
    color7_write_reg(color7_$port_50, color7_$port_addr, 16#80);
    color7_write_reg(color7_$port_60, color7_$port_addr, 16#80);
    color7_write_reg(color7_$port_70, color7_$port_addr, 16#80);
  end;

  color7_$video_ctl(addr(dcte), true);
  smd_$add_device(0, addr(dcte));
done:
  color7_$ioinit := status.all;
end;
