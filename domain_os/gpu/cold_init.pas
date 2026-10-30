{ GPU_$COLD_INIT - initialize the graphics processor's driver at boot.

  Image addresses:
    sau5  0x00E3732C  GPU_$COLD_INIT

  - Ends with two register writes to the processor, tried once more after
    a reset when the first try fails; the status is dropped.
  - In OS_INIT_PROC: gpu_$pio_write and gpu_$reset are .TEXT's, declared
    forward in gpu/gpu.pas.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure gpu_$cold_init;
var
  cmds: array[1..8] of pinteger;
  status: status_$t;
  gpu_stat: pinteger;
  done: integer;
  i: integer;
begin
  gpu_$user_pid := 0;
  ec_$init(gpu_$done_ec);
  ec_$init(gpu_$page_ec);
  ec_$init(gpu_ec);
  ml_$exclusion_init(gpu_$ml_lock);
  diag_mode := false;
  page_faults_ok := true;
  page_count := 0;
  page_table := nil;
  for i := 1 to 64 do
    page_max[i] := 0;
  diag_buf1_pa := 0;
  diag_buf2_pa := 0;
  diag_wired := 0;
  wait_ecs[gpu_wait_page] := addr(gpu_$page_ec);
  wait_ecs[gpu_wait_done] := addr(gpu_$done_ec);
  wait_ecs[gpu_wait_clock] := addr(time_$clockh_ec);
  wait_ecs[gpu_wait_draw] := addr(color2_$int_ec);
  lock_waiters := 0;
  context_pid := 0;
  gpu_$present := true;

  cmds[1] := 16#41C3;
  cmds[2] := 2;
  cmds[3] := 16#800E;
  cmds[4] := 0;
  cmds[5] := 16#41C3;
  cmds[6] := 2;
  cmds[7] := 16#8010;
  cmds[8] := 0;
  gpu_$pio_write(cmds, 8, done, gpu_stat, status);
  if status.all <> status_$ok then begin
    gpu_$reset;
    gpu_$pio_write(cmds, 8, done, gpu_stat, status);
  end;
end;
