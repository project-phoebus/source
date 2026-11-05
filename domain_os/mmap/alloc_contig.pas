{ MMAP_$ALLOC_CONTIG - allocate contiguous pages.

  Image addresses:
    sau2  0x00E0D8F0  MMAP_$ALLOC_CONTIG
    sau4  0x0F80DF44  MMAP_$ALLOC_CONTIG
    sau6  0x7800E072  MMAP_$ALLOC_CONTIG
    sau7  0x3C40F2B6  MMAP_$ALLOC_CONTIG
    sau8  0x03C0E7A2  MMAP_$ALLOC_CONTIG
    sau9  0x3C40F876  MMAP_$ALLOC_CONTIG

  Assume we're called with the PMAP lock held.

  - With the page-descriptor page maps the pageable pages are searched
    from MMAP_$LPPN up for a run of n that does not cross a 64 KB
    boundary (its first and last pages agree in address bit 16): each
    page of the run is unwired and on a working set list, on the free,
    pure or impure pool (lists 0..2), or else clean once it is out of
    the MMU.  A page that fails ends the run.
  - The run's pages are then taken: those of the free pool off their
    list with interrupts masked, the others out of their segments
    (AST_$REMOVE_PAGE).
  - Without them (the SAU2) no contiguous pages are ever allocated: the
    first page number is cleared.

  Status stored:
    status_$ok: the n pages are in ppns
    status_$mmap_contig_pages_unavailable: no run of n pages was found
}

procedure mmap_$alloc_contig(n: integer; out ppns: univ mmap_$vpn_list_t;
                             out status: status_$t);
%if pmmu_page_maps %then
var
  on_free_pool: array[1..32] of boolean;
  i: integer;
  ppn: linteger;
  count: integer;
  entry: ast_$pmap_entry_ptr_t;
  old_sr: integer;
begin
  status.all := status_$ok;
  for i := 1 to 32 do
    on_free_pool[i] := false;

  { the search: count pages of a run so far, marked for those on the
    free pool (32 marks; n is not checked against them) }
  ppn := mmap_$lppn - 1;
  count := 0;
  while (ppn < mmap_$hppn) and then (count < n) do begin
    ppn := ppn + 1;
    if ((ppn * 1024) & 16#10000) = (((n + ppn - 1) * 1024) & 16#10000) then
      with mmap[ppn]: page do
        if page.in_wsl and then (page.wire_count = 0) then
          if page.wsl_index <= 2 then begin
            count := count + 1;
            ppns[count] := ppn;
            if page.wsl_index = 0 then
              on_free_pool[count] := true;
            next;
          end
          else begin
            entry := addr(ast_pmaps[page.segment][page.seg_offset]);
            entry^.flags := entry^.flags - [ast_$pmap_resident];
            mmu_$purge;
            if not (ast_$pmap_modified in entry^.flags)
               and then not page.modified then begin
              count := count + 1;
              ppns[count] := ppn;
              next;
            end;
          end;

    { the run ends here }
    for i := 1 to count do
      on_free_pool[i] := false;
    count := 0;
  end;

  if count < n then
    status.all := status_$mmap_contig_pages_unavailable
  else
    for i := 1 to count do
      if on_free_pool[i] = true then begin
        old_sr := set_sr(16#2700);
        mmap_$remove_from_wsl(mmap[ppns[i]], ppns[i]);
        discard(set_sr(old_sr));
      end
      else
        ast_$remove_page(ppns[i]);
end;
%else
begin
  ppns[1] := 0;
  status.all := status_$mmap_contig_pages_unavailable;
end;
%endif
