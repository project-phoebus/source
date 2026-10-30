{ MEM_LITES - the status-lights process: redraw the lights every 125 ms.

  Image addresses:
    sau2  0x00E0C39C  MEM_LITES

  - The process marks itself of type 10, takes ml_$mem_lites_lock, and
    draws the two words LITES_LOC points at with SMD_$LITES every 31250
    ticks (125 ms), until LITES_LOC is nil; then it unbinds itself.

  Status stored: none.
}

procedure mem_lites;
var
  status: status_$t;
  unused_6: integer;                      { stand-in }
  delay: time_$clock_t;
begin
  proc1_$set_type(proc1_$current, 10);
  proc1_$set_lock(ml_$mem_lites_lock);

  delay.high := 0;
  delay.low := 31250;

  repeat
    time_$wait(time_$relative, delay, status);
    if lites_loc = nil then exit;
    smd_$lites(lites_loc^[1], mem_lites_row1);
    smd_$lites(lites_loc^[2], mem_lites_row2);
  until false;

  proc1_$clr_lock(ml_$mem_lites_lock);
  proc1_$unbind(proc1_$current, status);
end;
