{ GPU_$SET_PAGE_LIMITS - set the current process's limits on the
  physical pages the graphics processor may hold for it.

  Image addresses:
    sau5  0x00E7412E  GPU_$SET_PAGE_LIMITS
    sau6  0x7807B0A6  GPU_$SET_PAGE_LIMITS

  - A maximum below the pages held releases them down to it: the
    processor taken (unless held) and, outside diagnostic mode, given
    back.
  - Bad limits get 16#2D000C (status_$gpu_dma_command_error).

  Status stored:
    status_$ok: the limits were set
    status_$gpu_not_initialized: the process did not open the processor
    status_$gpu_dma_command_error: min_pages is negative or above
      max_pages, or max_pages is not positive
    gpu_$lock's status: the processor could not be taken
}

procedure gpu_$set_page_limits(in min_pages: integer; in max_pages: integer;
                               out status_ret: status_$t);
begin
  if page_max[proc1_$current] <= 0 then begin
    status_ret.all := status_$gpu_not_initialized;
    return;
  end;
  if (min_pages > max_pages) or else (min_pages < 0)
     or else (max_pages <= 0) then begin
    status_ret.all := status_$gpu_dma_command_error;
    return;
  end;
  status_ret.all := status_$ok;
  page_min[proc1_$current] := min_pages;
  page_max[proc1_$current] := max_pages;
  if max_pages < pages_wired[proc1_$current] then begin
    if gpu_$user_pid <> proc1_$current then
      gpu_$lock(status_ret);
    if status_ret.all = status_$ok then begin
      gpu_$unwire_process_pages(max_pages,
                                context_pid = proc1_$current);
      if not diag_mode then
        gpu_$unlock;
    end;
  end;
end;
