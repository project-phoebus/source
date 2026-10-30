{ gpu_$lock - take the graphics processor for the current process.

  Image addresses:
    sau5  0x00E73590  gpu_$lock (module-local)

  - It waits with GPU_$ML_LOCK released, at most 100 clock ticks and
    until the process is told to quit; a quit is noted as seen.

  Status stored:
    status_$ok: the process holds the processor
    status_$gpu_device_not_available: 100 clock ticks passed
    status_$gpu_wait_quit: the process was told to quit
}

procedure gpu_$lock(out status: status_$t); internal;
var
  result: integer;
  deadline: integer32;
  target: integer32;
begin
  result := 0;
  if gpu_$user_pid <> proc1_$current then begin
    deadline := time_$clockh + 100;
    ml_$exclusion_start(gpu_$ml_lock);
    lock_waiters := lock_waiters + 1;
    while gpu_$user_pid <> 0 do begin
      target := gpu_ec.value + 1;
      ml_$exclusion_stop(gpu_$ml_lock);
      result := ec_$wait(addr(gpu_ec), addr(time_$clockh_ec),
                         addr(fim_$quit_ec[proc1_$as_id]),
                         target, deadline,
                         fim_$quit_value[proc1_$as_id] + 1);
      ml_$exclusion_start(gpu_$ml_lock);
      if result <> 0 then
        exit;
    end;
    if result = 0 then
      gpu_$user_pid := proc1_$current;
    lock_waiters := lock_waiters - 1;
    ml_$exclusion_stop(gpu_$ml_lock);
  end;

  case result of
    0: begin
      status.all := status_$ok;
    end;
    1: begin
      status.all := status_$gpu_device_not_available;
    end;
    2: begin
      fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;
      status.all := status_$gpu_wait_quit;
    end;
  end;
end;
