{ GPU_$TERM - shut the graphics processor down.

  Image addresses:
    sau2  0x00E7080E  GPU_$TERM
    sau5  0x00E73D34  GPU_$TERM
    sau6  0x7807ACB0  GPU_$TERM

  - Without `gpu_driver' (base/config.ins.pas; the SAU2) an empty
    procedure.
  - Only for a process that opened the processor; one with pages in the
    table, or holding it in diagnostic mode, waits until it holds it.
  - When the processor holds the process's pages, or in diagnostic mode,
    it is stopped, and reset on any failure; diagnostic mode is left.
  - The statuses are ignored.

  Status stored: none.
}

procedure gpu_$term;
%if gpu_driver %then
var
  cmd: gpu_cmd0_t;
  status: status_$t;
  pa: integer32;
  gpu_stat: pinteger;
  done: integer;
%endif
begin
%if gpu_driver %then
  if page_max[proc1_$current] > 0 then begin
    if (pages_wired[proc1_$current] <> 0) or else
       (diag_mode and then (gpu_$user_pid = proc1_$current)) then begin
      while gpu_$user_pid <> proc1_$current do
        gpu_$lock(status);
      if diag_mode or else (context_pid = proc1_$current) then begin
        context_pid := 0;
        gpu_$wait_pio(gpu_stat, status);
        if status.all <> status_$ok then
          gpu.abort_word := 0;
        cmd.op := 16#41E2;
        cmd.len := 0;
        gpu_$pio_write(cmd, 2, done, gpu_stat, status);
        if status.all = status_$ok then
          gpu_$wait_pio_timed(2, gpu_stat, status);
        if status.all <> status_$ok then
          gpu_$reset;
        if diag_mode then begin
          gpu_$unwire_buffers;
          if diag_buf2_pa <> 0 then
            wp_$unwire(diag_buf2_pa);
          if diag_buf1_pa <> 0 then
            wp_$unwire(diag_buf1_pa);
          diag_buf2_pa := 0;
          diag_buf1_pa := 0;
          pa := mmu_$vtop(integer32(addr(gpu)), status);
          if status.all = status_$ok then
            mmu_$install(pa, addr(gpu), 0, 16#16);
          diag_mode := false;
        end;
      end;
      gpu_$unwire_process_pages(0, false);
      gpu_$wait_pio_timed(4, gpu_stat, status);
      gpu_$unlock;
    end;
    page_max[proc1_$current] := 0;
  end;
%endif
end;
