{ gpu_$reset - reset the graphics processor.

  Image addresses:
    sau5  0x00E73CC6  gpu_$reset (module-local)

  - It forgets the loaded context and waits up to 4 clock ticks for the
    processor; the wait's status is dropped.

  Status stored: none.
}

procedure gpu_$reset;
  internal;
var
  gpu_stat: pinteger;
  status: status_$t;
begin
  context_pid := 0;
  gpu.reset_word := 0;
  gpu_$wait_pio_timed(4, gpu_stat, status);
end;
