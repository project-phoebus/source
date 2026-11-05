{ MMAP_$WS_SCAN - take pages off a working set list for the paging
  daemon.

  Image addresses:
    sau2  0x00E0D364  MMAP_$WS_SCAN
    sau2  0x00E0D274  mmap_$move_pages_to_wsl_type (nested)
    sau4  0x0F80D9D4  MMAP_$WS_SCAN
    sau4  0x0F80D8E4  mmap_$move_pages_to_wsl_type (nested)
    sau6  0x7800DB1E  MMAP_$WS_SCAN
    sau7  0x3C40ED6A  MMAP_$WS_SCAN
    sau7  0x3C40EC90  mmap_$move_pages_to_wsl_type (nested)
    sau8  0x03C0E256  MMAP_$WS_SCAN
    sau8  0x03C0E17C  mmap_$move_pages_to_wsl_type (nested)
    sau9  0x3C40F2CE  MMAP_$WS_SCAN
    sau9  0x3C40F1CC  mmap_$move_pages_to_wsl_type (nested)

  - An index outside 5..MMAP_$WSL_HI_MARK crashes the system.  At most
    page_count pages are examined from the head, until the number asked
    for is taken.
  - The first mode takes dirty pages whose object has attribute bit 12;
    the second passes over (and clears) referenced pages, taking the
    rest.
  - Unwired pages leave the MMU and go to pools 2, 1, 3 and 4 by kind;
    the result is the number of pages examined.

  Status stored: none.
}

function mmap_$ws_scan(wsl_index: pinteger; mode: boolean;
                       pages_needed: linteger; unused: integer32): linteger;
label
  10;
var
  page_count: linteger;
  chain_remote: linteger;
  chain_local: linteger;
  chain_pure: linteger;
  vpn: linteger;
  next_p: linteger;
  removed: linteger;
  examined: linteger;
  chain_impure: linteger;
  page: ^mmap_$mmape_t;
  seg_entry: ^ast_$pmap_entry_t;
  flush: boolean;

  { mmap_$move_pages_to_wsl_type - hand a chain of pages to a pool.

    - Nested in MMAP_$WS_SCAN.  Each page of the chain (through
      next_vpn) is linked back to the one before it and given the
      pool's index (priority wsl_index in the first mode, else 0).
    - The chain goes into the pool, whose count goes up by its length.

    Status stored: none.
  }

  procedure mmap_$move_pages_to_wsl_type(vpn_head: linteger;
                                         page_type: integer);
  var
    pri: integer;
    count: linteger;
    current: linteger;
    last: linteger;
    head: linteger;
    tail: linteger;
  begin
    count := 0;
    current := vpn_head;
    last := 0;
    if mode then
      pri := wsl_index
    else
      pri := 0;

    while current <> 0 do begin
      count := count + 1;
      with mmap[current] do begin
        prev_vpn := last;
        priority := pri;
        wsl_index := page_type;
        last := current;
        current := next_vpn;
      end;
    end;

    with mmap_$wsl[page_type] do begin
      if page_count = 0 then begin
        head_vpn := last;
        mmap[last].next_vpn := vpn_head;
        mmap[vpn_head].prev_vpn := last;
      end
      else begin
        head := head_vpn;
        tail := mmap[head].next_vpn;
        mmap[head].next_vpn := vpn_head;
        mmap[vpn_head].prev_vpn := head;
        mmap[tail].prev_vpn := last;
        mmap[last].next_vpn := tail;
      end;
      page_count := page_count + count;
    end;
  end;

begin
  if (wsl_index < 5) or else (wsl_index > mmap_$wsl_hi_mark) then
    crash_system(status_$mmap_illegal_wsl_index);
  mmap_$ws_scan_cnt := mmap_$ws_scan_cnt + 1;
  chain_impure := 0;
  chain_local := 0;
  chain_remote := 0;
  chain_pure := 0;
  removed := 0;
  examined := 0;

  with mmap_$wsl[wsl_index]: wsl do begin
    page_count := wsl.page_count;
    vpn := wsl.head_vpn;

    while examined < page_count do begin
      page := addr(mmap[vpn]);
      seg_entry := addr(ast_pmaps[page^.segment][page^.seg_offset]);
      next_p := page^.prev_vpn;

%if pmmu_page_maps or region_mmu %then
      if mode then begin
        if not ((page^.modified
                 or (ast_$pmap_modified in seg_entry^.flags))
                and then not page^.flags2_7
                and then ((ast[page^.segment].aote^.attr_flags & 16#1000)
                          <> 0)) then
          goto 10;
      end
      else if ast_$pmap_used in seg_entry^.flags then begin
        seg_entry^.flags := seg_entry^.flags - [ast_$pmap_used];
        goto 10;
      end;
%else
      if mode then begin
        if not ((page^.modified or ((pft[vpn].w_02 & 16#4000) <> 0))
                and then not page^.flags2_7
                and then ((ast[page^.segment].aote^.attr_flags & 16#1000)
                          <> 0)) then
          goto 10;
      end
      else if (pft[vpn].w_02 & 16#2000) <> 0 then begin
        pft[vpn].w_02 := pft[vpn].w_02 & ~16#2000;
        goto 10;
      end;
%endif

      { the page is taken }
      removed := removed + 1;
      mmap[page^.next_vpn].prev_vpn := next_p;
      mmap[next_p].next_vpn := page^.next_vpn;
      if page^.wire_count = 0 then begin
%if pmmu_page_maps or region_mmu %then
        { the translations are flushed once, after the walk }
        seg_entry^.flags := seg_entry^.flags - [ast_$pmap_resident];
        if (ast_$pmap_modified in seg_entry^.flags)
           or else page^.modified then begin
%else
        if ast_$pmap_resident in seg_entry^.flags then begin
          seg_entry^.flags := seg_entry^.flags - [ast_$pmap_resident];
          mmu_$remove(vpn);
        end;
        if ((pft[vpn].w_02 & 16#4000) <> 0)
           or else page^.modified then begin
%endif
          if page^.flags2_7 then
            flush := ast[page^.segment].aote^.dtm.high16 <> 0
          else
            flush := ast[page^.segment].aote^.location_hi < 0;
          if flush then begin
            page^.next_vpn := chain_remote;
            chain_remote := vpn;
          end
          else begin
            page^.next_vpn := chain_local;
            chain_local := vpn;
          end;
        end
        else if page^.impure then begin
          page^.next_vpn := chain_pure;
          chain_pure := vpn;
        end
        else begin
          page^.next_vpn := chain_impure;
          chain_impure := vpn;
        end;
      end
      else begin
        mmap_$pageable_pages := mmap_$pageable_pages - 1;
        page^.in_wsl := false;
      end;

  10:
      vpn := next_p;
      examined := examined + 1;
      if removed >= pages_needed then
        exit;
    end;
%if pmmu_page_maps or region_mmu %then
    mmu_$purge;
%endif

    wsl.page_count := wsl.page_count - removed;
    if examined >= wsl.scan_pos then
      wsl.scan_pos := 0
    else
      wsl.scan_pos := wsl.scan_pos - examined;
    wsl.head_vpn := vpn;
  end;
  mmap_$ws_remove := mmap_$ws_remove + removed;

  if chain_impure <> 0 then
    mmap_$move_pages_to_wsl_type(chain_impure, 2);
  if chain_pure <> 0 then
    mmap_$move_pages_to_wsl_type(chain_pure, 1);
  if chain_local <> 0 then
    mmap_$move_pages_to_wsl_type(chain_local, 3);
  if chain_remote <> 0 then
    mmap_$move_pages_to_wsl_type(chain_remote, 4);

  mmap_$ws_scan := examined;
end;
