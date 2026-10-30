{ gpu_$wire_page - wire a page for the graphics processor and give it
  the mapping.

  Image addresses:
    sau5  0x00E73974  gpu_$wire_page (module-local)

  - Pages are released first: the process's down to one below its
    limit, then the table's from its head while no more than 256 (and no
    more than the table holds) are left above the pageable lower limit.
  - A page already in the table is released before it is wired again.

  Status stored:
    status_$ok: the page was wired and the processor given the mapping
    mst_$wire's status: the page could not be wired
    gpu_$pio_write's status: the processor was not told the mapping (the
      page joins the table all the same)
}

procedure gpu_$wire_page(va: integer32; out status: status_$t); internal;
var
  free: integer;
  ppn: integer32;
  next: integer32;
  cmd: gpu_cmd_t;
  done: integer;
  gpu_stat: pinteger;
begin
  gpu_$unwire_process_pages(page_max[proc1_$current] - 1, true);
  while page_count <> 0 do begin
    free := mmap_$pageable_pages - mmap_$pageable_pages_lower_limit;
    if free > 256 then
      exit;
    if free > page_count then
      exit;
    gpu_$unwire_page(page_head, true);
  end;

  ppn := mst_$wire(va & 16#FFFFFC00, status);
  if status.all <> status_$ok then
    return;
  if page_table^[ppn].info <> 0 then
    gpu_$unwire_page(ppn, true);

  cmd.op := 16#41E0;
  cmd.len := 4;
  cmd.arg1 := va & 16#FFFFFC00;
  cmd.arg2 := lshft(ppn, 10);
  gpu_$pio_write(cmd, 6, done, gpu_stat, status);

  if page_count = 0 then begin
    page_table^[ppn].next := ppn;
    page_table^[ppn].prev := ppn;
    page_head := ppn;
  end
  else begin
    next := page_table^[page_head].next;
    page_table^[page_head].next := ppn;
    page_table^[ppn].prev := page_head;
    page_table^[ppn].next := next;
    page_table^[next].prev := ppn;
  end;
  page_count := page_count + 1;
  pages_wired[proc1_$current] := pages_wired[proc1_$current] + 1;
  page_table^[ppn].info := proc1_$current ! cmd.arg1;
end;
