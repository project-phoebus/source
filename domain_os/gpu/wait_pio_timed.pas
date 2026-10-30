{ gpu_$wait_pio_timed - wait, for a number of clock ticks, for the
  graphics processor to take a programmed I/O word.

  Image addresses:
    sau5  0x00E73744  gpu_$wait_pio_timed (module-local)

  - The status word is read until the clock passes ticks from now, and
    once more; gpu_stat is the last one read.
  - The error bit gives 16#2D000A (status_$gpu_illegal_page_limits).

  Status stored:
    status_$ok: the processor is not busy (bit 0) and its error bit (2)
      is clear
    status_$gpu_illegal_page_limits: the error bit is set
    status_$gpu_not_ready_for_pio: the processor is still busy
}

procedure gpu_$wait_pio_timed(ticks: integer32; out gpu_stat: pinteger;
                              out status: status_$t);
  internal;
label
  10;
var
  deadline: integer32;
  st: pinteger;
begin
  status.all := status_$ok;
  deadline := ticks + time_$clockh;
  while deadline >= time_$clockh do begin
    st := gpu.status;
    if (st & 5) = 0 then
      goto 10;
  end;
  st := gpu.status;
  if (st & 5) <> 0 then
    if (st & 1) = 0 then
      status.all := status_$gpu_illegal_page_limits
    else
      status.all := status_$gpu_not_ready_for_pio;
10:
  gpu_stat := st;
end;
