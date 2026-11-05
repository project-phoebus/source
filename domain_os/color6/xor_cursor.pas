{ COLOR6_$XOR_CURSOR - draw or remove the cursor.

  Image addresses:
    sau7  0x3C48CBD6  COLOR6_$XOR_CURSOR

  - At the unit's page, under the SMD request lock (PROC1_$SET_LOCK).
  - With wait, once the FIFO is idle (color6_wait_idle) the board's busy
    flag is polled up to 8192 times.
  - A busy board gives false; otherwise the cursor's position registers
    are set (the cursor's number in the x register's top 4 bits), or to
    -1 to remove it, and the result is true.  With bit 5 of the swapped
    control word the board is waited for twice, up to 524287 polls each.

  Status stored: none.
}

[section(color6_wired_proc, wired_data)]
function color6_$xor_cursor(dcte: color6_$dcte_ptr_t; cursor_num: pinteger;
                            pos: smd_$pos_t;
                            in limits: smd_$window_limits_t;
                            remove: boolean; wait: boolean): boolean;
  options(val_param);
var
  info: color6_$info_ptr_t;
  regs: color6_$regs_ptr_t;
  saved: color6_$byte_t;
  count: integer32;
  st: color6_$ctl_t;
  xy: pinteger;
  ready: boolean;
begin
  info := dcte^.info;
  regs := info^.regs;
  proc1_$set_lock(ml_$smd_request_lock);
  saved := color6_get_page(info^.regs);
  color6_set_page(info^.regs, dcte^.cnum);
  if wait then
    if color6_wait_idle(dcte) then begin
      count := 0;
      repeat
        count := count + 1;
      until (count = 8192) or not regs^.busy;
    end;
  if regs^.busy then
    color6_$xor_cursor := false
  else begin
    st := color6_$ctl_t(color6_swap16(regs^.ctl));
    if remove then begin
      regs^.cursor_x := 16#FFFF;
      regs^.cursor_y := 16#FFFF;
    end
    else begin
      xy := lshft(cursor_num, 12) ! pos.column;
      regs^.cursor_x := color6_swap16(xy);
      regs^.cursor_y := color6_swap16(pos.line);
    end;
    if 5 in st then begin
      count := 0;
      repeat
        ready := not regs^.busy;
        count := count + 1;
      until ready or (count = 524287);
      count := 0;
      repeat
        ready := 13 in regs^.ctl;
        count := count + 1;
      until ready or (count = 524287);
    end;
    color6_$xor_cursor := true;
  end;
  color6_set_page(info^.regs, saved);
  proc1_$clr_lock(ml_$smd_request_lock);
end;
