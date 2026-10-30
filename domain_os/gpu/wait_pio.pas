{ gpu_$wait_pio - wait, by a bounded spin, for the graphics processor to
  take a programmed I/O word.

  Image addresses:
    sau5  0x00E736F0  gpu_$wait_pio (module-local)

  - The status word is read at most 25000 times; gpu_stat is the last
    one read.
  - The error bit gives 16#2D000A (status_$gpu_illegal_page_limits).

  Status stored:
    status_$ok: the processor is not busy (bit 0) and its error bit (2)
      is clear
    status_$gpu_not_ready_for_pio: the processor is still busy
    status_$gpu_illegal_page_limits: the error bit is set
}

procedure gpu_$wait_pio(out gpu_stat: pinteger; out status: status_$t);
  internal;
var
  i: integer;
  st: pinteger;
begin
  for i := 1 to 25000 do begin
    st := gpu.status;
    if (st & 1) = 0 then
      exit;
  end;
  if (st & 5) = 0 then
    status.all := status_$ok
  else if (st & 1) = 0 then
    status.all := status_$gpu_illegal_page_limits
  else
    status.all := status_$gpu_not_ready_for_pio;
  gpu_stat := st;
end;
