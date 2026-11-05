{ color6_drain_fifo - wait until the board's FIFO is empty and idle.

  Image addresses:
    sau7  0x3C48CA30  color6_drain_fifo (module-local)

  - While the FIFO holds words, the count is read every 2500 ticks: a
    count that grows ends the wait, one that stays 500 times is a
    timeout.
  - With the control word's bit 12 set, its bit 11 is set and waited
    for to clear, 2500 times every 500 ticks.

  Status stored:
    status_$ok: the FIFO drained, or its count grew
    smd_$access_denied: a timeout
}

[section(color6_wired_proc, wired_data)]
procedure color6_drain_fifo(dcte: color6_$dcte_ptr_t;
                            out status: status_$t);
  internal;
label
  timeout;
var
  short_delay: static time_$clock_t := [high := 0, low := 500];   { +0x4 }
  long_delay: static time_$clock_t := [high := 0, low := 2500];   { +0xC }
  count: pinteger;
  last: pinteger;
  tries: integer;
  regs: color6_$regs_ptr_t;
  i: integer;
  wstatus: status_$t;
begin
  status.all := status_$ok;
  count := color6_fifo_count(dcte);
  if count <> 0 then begin
    tries := 500;
    repeat
      time_$wait(time_$relative, long_delay, wstatus);
      last := count;
      count := color6_fifo_count(dcte);
      if count = 0 then
        exit;
      if count > last then
        return;
      if count = last then
        tries := tries - 1
      else
        tries := 500;
    until tries = 0;
    if tries = 0 then
      goto timeout;
  end;
  regs := dcte^.info^.regs;
  if not (12 in regs^.ctl) then
    return;
  regs^.ctl := regs^.ctl + [11];
  for i := 1 to 2500 do begin
    if not (11 in regs^.ctl) then
      return;
    time_$wait(time_$relative, short_delay, wstatus);
  end;
timeout:
  status.all := smd_$access_denied;
end;
