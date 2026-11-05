{ gpu_$reset - reset the graphics processor.

  Image addresses:
    sau5  0x00E73CC6  gpu_$reset (module-local)
    sau6  0x7807ABD6  gpu_$reset (module-local)

  - It forgets the loaded context and waits up to 4 clock ticks for the
    processor; the wait's status is dropped.
  - With `gpu_reset_registers' (base/config.ins.pas) it then writes the
    registers 16#71BA (16#000D) and 16#2007 (the processor's status word
    with bit 7), as GPU_$COLD_INIT does; their status is dropped.

  Status stored: none.
}

procedure gpu_$reset;
  internal;
var
  gpu_stat: pinteger;
  status: status_$t;
%if gpu_reset_registers %then
  reg_cmd: gpu_cmd_t;
  done: integer;
  reg_stat: pinteger;
%endif
begin
  context_pid := 0;
  gpu.reset_word := 0;
  gpu_$wait_pio_timed(4, gpu_stat, status);
%if gpu_reset_registers %then

  { the two registers the reset leaves to the driver }
  reg_cmd.op := 16#41C3;
  reg_cmd.len := 2;
  reg_cmd.arg1 := 16#71BA000D;
  gpu_$pio_write(reg_cmd, 4, done, reg_stat, status);
  reg_cmd.op := 16#41C3;
  reg_cmd.len := 2;
  reg_cmd.arg1 := integer(gpu.status) ! 16#20070000 ! 16#80;
  gpu_$pio_write(reg_cmd, 4, done, reg_stat, status);
%endif
end;
