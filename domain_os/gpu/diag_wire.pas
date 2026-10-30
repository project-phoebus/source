{ GPU_$DIAG_WIRE - wire a diagnostic program's buffer for the graphics
  processor.

  Image addresses:
    sau5  0x00E74612  GPU_$DIAG_WIRE

  - A page count of 0 or less unwires the pages wired before.
  - A page that cannot be wired unwires the pages wired so far.

  Status stored:
    status_$ok: the pages were wired, or unwired
    status_$gpu_not_initialized: the process did not open the processor
    status_$gpu_device_not_available: the process does not hold the
      processor in diagnostic mode
    status_$gpu_buffer_already_wired: pages are wired already
    status_$gpu_buffer_too_large: more than 256 pages, or more than the
      pageable pages leave above their lower limit plus 128
    mst_$wire's status: a page could not be wired
}

procedure gpu_$diag_wire(in buf: univ gpu_$diag_buffer_t; in n_pages: integer;
                         out page_pas: univ gpu_$page_list_t;
                         out status_ret: status_$t);
var
  i: integer;
  pa: integer32;
begin
  status_ret.all := status_$ok;
  if page_max[proc1_$current] <= 0 then
    status_ret.all := status_$gpu_not_initialized
  else if not ((gpu_$user_pid = proc1_$current) and diag_mode) then
    status_ret.all := status_$gpu_device_not_available;
  if status_ret.all <> status_$ok then
    return;

  if n_pages <= 0 then
    gpu_$unwire_buffers
  else if diag_wired <> 0 then
    status_ret.all := status_$gpu_buffer_already_wired
  else if (n_pages > 256) or else
          (n_pages + mmap_$pageable_pages_lower_limit + 128 >
           mmap_$pageable_pages) then
    status_ret.all := status_$gpu_buffer_too_large
  else
    for i := 1 to n_pages do begin
      pa := mst_$wire(integer32(addr(buf[i])), status_ret);
      if status_ret.all <> status_$ok then begin
        gpu_$unwire_buffers;
        return;
      end;
      diag_wired := i;
      page_pas[i] := pa;
      wired_pages[i] := pa;
    end;
end;
