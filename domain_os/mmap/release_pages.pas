{ MMAP_$RELEASE_PAGES - move an address space's unwired pages to the
  global pools.

  Image addresses:
    sau2  0x00E0CFF8  MMAP_$RELEASE_PAGES
    sau8  0x03C0DEF4  MMAP_$RELEASE_PAGES
    sau9  0x3C40EF44  MMAP_$RELEASE_PAGES

  - Each unwired page of the list on the address space's working set
    list is taken off it and added to a pool, not at its tail.
  - A clean page goes to pool 1 when impure, else 2; a dirty one to
    pool 4 when its object needs a flush, else 3.

  Status stored: none.
}

procedure mmap_$release_pages(pid: pinteger;
                              in vpn_array: univ mmap_$vpn_list_t;
                              count: pinteger);
var
  wsl_index: pinteger;
  i: pinteger;
  pool: integer;
  vpn: linteger;
  dirty: boolean;
  flush: boolean;
%if pmmu_page_maps %then
  entry: ast_$pmap_entry_ptr_t;
%endif
begin
  wsl_index := mmap_$ws_owner[pid];

  for i := 1 to count do begin
    vpn := vpn_array[i];
    with mmap[vpn]: page do begin
      if page.wsl_index <> wsl_index then
        next;
      if not page.in_wsl then
        next;
      if page.wire_count <> 0 then
        next;

%if pmmu_page_maps %then
      entry := addr(ast_pmaps[page.segment][page.seg_offset]);
      mmap_$remove_from_wsl(page, vpn);

      dirty := (ast_$pmap_modified in entry^.flags) or page.modified;
%else
      mmap_$remove_from_wsl(page, vpn);

      dirty := ((pft[vpn].w_02 & 16#4000) <> 0) or page.modified;
%endif
      if not dirty then begin
        if page.impure then
          pool := 1
        else
          pool := 2;
      end
      else begin
        if page.flags2_7 then
          flush := ast[page.segment].aote^.dtm.high16 <> 0
        else
          flush := ast[page.segment].aote^.loc_flags < 0;
        if flush then
          pool := 4
        else
          pool := 3;
      end;

      mmap_$add_to_wsl(page, vpn, pool, true);
    end;
  end;
end;
