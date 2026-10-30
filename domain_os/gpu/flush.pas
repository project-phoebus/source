{ GPU_$FLUSH - take the current process's pages out of the graphics
  processor.

  Image addresses:
    sau5  0x00E7405A  GPU_$FLUSH

  - A process with no pages in the table returns at once; otherwise it
    waits until it holds the processor, and outside diagnostic mode
    gives it back at the end.
  - When the processor holds the process's pages, or in diagnostic mode,
    the processor is stopped first; the pages are released all the same.

  Status stored:
    status_$ok: the pages were released
    status_$gpu_not_initialized: the process did not open the processor
    gpu_$lock's, gpu_$pio_write's or gpu_$wait_pio_timed's status: the
      last step failed
}

procedure gpu_$flush(out status_ret: status_$t);
var
  cmd: gpu_cmd0_t;
  gpu_stat: pinteger;
  done: integer;
begin
  status_ret.all := status_$ok;
  if page_max[proc1_$current] <= 0 then begin
    status_ret.all := status_$gpu_not_initialized;
    return;
  end;
  if pages_wired[proc1_$current] = 0 then
    return;

  while gpu_$user_pid <> proc1_$current do
    gpu_$lock(status_ret);
  if diag_mode or else (context_pid = proc1_$current) then begin
    context_pid := 0;
    gpu_$wait_pio(gpu_stat, status_ret);
    if status_ret.all <> status_$ok then
      gpu.abort_word := 0;
    cmd.op := 16#41E2;
    cmd.len := 0;
    gpu_$pio_write(cmd, 2, done, gpu_stat, status_ret);
    if status_ret.all = status_$ok then
      gpu_$wait_pio_timed(2, gpu_stat, status_ret);
  end;
  gpu_$unwire_process_pages(0, false);
  if not diag_mode then
    gpu_$unlock;
end;
