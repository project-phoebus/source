{ gpu_$pio_write - send words to the graphics processor's data port by
  programmed I/O.

  Image addresses:
    sau5  0x00E737A2  gpu_$pio_write (module-local)

  - Each word waits for the processor; the first also needs the status
    word's ready bit (5).
  - The first failure stops it: done is the number of words sent,
    gpu_stat the last status word read (undefined when count is 0).

  Status stored:
    status_$ok: the words were sent
    status_$gpu_not_ready_for_pio: the processor was not ready for the
      first word
    gpu_$wait_pio's status: a wait failed
}

procedure gpu_$pio_write(in buf: univ gpu_$words_t; count: integer;
                         out done: integer; out gpu_stat: pinteger;
                         out status: status_$t);
  internal;
var
  i: integer;
  st: pinteger;
begin
  status.all := status_$ok;
  i := 0;
  while i < count do begin
    gpu_$wait_pio(st, status);
    if i = 0 then
      if (st & 16#20) = 0 then
        status.all := status_$gpu_not_ready_for_pio;
    if status.all <> status_$ok then
      exit;
    i := i + 1;
    gpu.data := buf[i];
  end;
  gpu_stat := st;
  done := i;
end;
