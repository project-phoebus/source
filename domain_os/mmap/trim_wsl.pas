{ mmap_$trim_wsl - take pages off a working set list and put them on the
  global pools.

  Image addresses:
    sau2  0x00E0C760  mmap_$trim_wsl (module-local)
    sau4  0x0F80CDC0  mmap_$trim_wsl (module-local)
    sau8  0x03C0D69E  mmap_$trim_wsl (module-local)
    sau9  0x3C40E6C8  mmap_$trim_wsl (module-local)

  - From the head along prev_vpn, up to page_count pages are examined
    until the number asked for is taken; within the first 32 (a big
    enough list, not a purge) referenced pages are passed over.
  - Taken unwired pages leave the MMU and go to pools 4, 3, 1 or 2 by
    dirt and purity.  A purge (16#3FFFFF) empties the list and clears
    its owner; else its count and head follow.

  Status stored: none.
}

procedure mmap_$trim_wsl(wsl_index: integer; pages_to_trim: linteger);
  internal;
var
  page: ^mmap_$mmape_t;
  seg_entry: ^ast_$pmap_entry_t;
  next_c: linteger;
  current: linteger;
  skip_count: linteger;
  collected: linteger;
  position: linteger;
  pool: integer;
  flush: boolean;
  is_purge: boolean;
  remaining: linteger;
  next_link: linteger;
  nv: linteger;
begin
  remaining := pages_to_trim;
  is_purge := pages_to_trim = 16#3FFFFF;
  skip_count := 0;
  collected := 0;

  with mmap_$wsl[wsl_index] do begin
    if not is_purge and then (32 + pages_to_trim < page_count) then
      skip_count := 32;

    { the walk }
    current := head_vpn;
    if page_count <> 0 then
      for position := 1 to page_count do begin
        page := addr(mmap[current]);
        seg_entry := addr(ast_pmaps[page^.segment][page^.seg_offset]);
        with page^ do begin
          next_link := prev_vpn;
%if pmmu_page_maps or region_mmu %then
          if (position > skip_count)
             or else not (ast_$pmap_used in seg_entry^.flags) then begin
%else
          if (position > skip_count)
             or else ((pft[current].w_02 & 16#2000) = 0) then begin
%endif
            mmap_$pageable_pages := mmap_$pageable_pages - 1;
            in_wsl := false;
            nv := next_vpn;
            mmap[nv].prev_vpn := next_link;
            mmap[next_link].next_vpn := nv;
            if wire_count = 0 then begin
              page^.prev_vpn := collected;
              collected := current;
%if pmmu_page_maps or region_mmu %then
              { the translations are flushed once, after the walk }
              seg_entry^.flags := seg_entry^.flags - [ast_$pmap_resident];
%else
              if ast_$pmap_resident in seg_entry^.flags then begin
                seg_entry^.flags := seg_entry^.flags - [ast_$pmap_resident];
                mmu_$remove(collected);
              end;
%endif
            end;
            remaining := remaining - 1;
          end;
        end;
        current := next_link;
        if remaining = 0 then
          exit;
      end;
%if pmmu_page_maps or region_mmu %then
    mmu_$purge;
%endif

    { the collected pages to the pools }
    while collected <> 0 do begin
      page := addr(mmap[collected]);
%if pmmu_page_maps or region_mmu %then
      seg_entry := addr(ast_pmaps[page^.segment][page^.seg_offset]);
      if page^.modified
         or else (ast_$pmap_modified in seg_entry^.flags) then begin
%else
      if page^.modified
         or else ((pft[collected].w_02 & 16#4000) <> 0) then begin
%endif
        if page^.flags2_7 then
          flush := ast[page^.segment].aote^.dtm.high16 <> 0
        else
          flush := ast[page^.segment].aote^.loc_flags < 0;
        if flush then
          pool := 4
        else
          pool := 3;
      end
      else if page^.impure then
        pool := 1
      else
        pool := 2;
      next_c := page^.prev_vpn;
      mmap_$add_to_wsl(page^, collected, pool, false);
      collected := next_c;
    end;

    if is_purge then begin
      page_count := 0;
      owner := 0;
      ws_timestamp := time_$clockh;
    end
    else begin
      page_count := remaining + page_count - pages_to_trim;
      head_vpn := current;
    end;
  end;
end;
