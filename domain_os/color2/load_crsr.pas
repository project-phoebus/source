{ COLOR2_$LOAD_CRSR - load a cursor into the graphics board's display
  memory.

  Image addresses:
    sau5  0x00E732C0  COLOR2_$LOAD_CRSR
    sau6  0x7807A1D2  COLOR2_$LOAD_CRSR

  - Under the SMD request lock (PROC1_$SET_LOCK), after the board is
    idle; a COLOR2_$BUSY_WAIT failure ends the routine.
  - The DN580's display (unless its status field of members 1 and 2 is
    2) gets the cursor set-up words and the bitmap in DISP_MEM_2KX1K;
    any other display eight FIFO words and the bitmap in DISP1_MEM.
  - The hot spot's x and y are not read.

  Status stored: none.
}

procedure color2_$load_crsr(in cursor_num: integer; in size: integer;
                            in hot_x: integer; in hot_y_adj: integer;
                            in bitmap: univ color2_$cursor_words_t);
label
  unlock;
var
  num: integer;
  rows: integer;
  base: integer;
  words: integer;
  row: integer;
  col: integer;
  n: integer;
  wait_status: status_$t;
begin
  num := cursor_num;
  rows := size;
  proc1_$set_lock(ml_$smd_request_lock);
  color2_$busy_wait(wait_status);
  if wait_status.all <> status_$ok then
    goto unlock;
  if smd_$graphic_device_id = smd_gdev_color2 then begin
    if kolor_ctl.status * [1, 2] = [2] then
      goto unlock;
    with kolor_ctl do begin
      repeat
      until not (15 in status);
      fifo_3002 := 1;
      fifo_3004 := 0;
      reg_3640 := 16#48B0;
    end;
    color2_$busy_wait(wait_status);
    base := num * 16 + 32;
    words := rows div 16 - 1;
    n := 1;
    for row := 0 to rows - 1 do
      for col := 0 to words do begin
        disp_mem_2kx1k[row + base][16#5E + col] := bitmap[n];
        n := n + 1;
      end;
  end
  else begin
    with kolor_ctl do begin
      repeat
      until (fifo_count & 16#F) >= 8;
      fifo := 16#48B0;
      fifo := 6;
      fifo := 0;
      fifo := 0;
      fifo := 0;
      fifo := 16#400;
      fifo := 16#400;
      fifo := 0;
    end;
    color2_$busy_wait(wait_status);
    base := num * 32 + 16#325;
    words := rows div 16 - 1;
    n := 1;
    for row := 0 to rows - 1 do
      for col := 0 to words do begin
        disp1_mem[(row + base) * 64 + 16#3E + col] := bitmap[n];
        n := n + 1;
      end;
  end;
unlock:
  proc1_$clr_lock(ml_$smd_request_lock);
end;
