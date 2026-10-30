{ ast_$invalidate_no_wait - mark an object's installed pages stale,
  without waiting.

  Image addresses:
    sau2  0x00E064B0  ast_$invalidate_no_wait (nested)
    sau9  0x3C407734  ast_$invalidate_no_wait (nested)

  Assume we're called with the AST lock held.

  - Nested in AST_$INVALIDATE.  The AOTE's segments from the end page's
    down to the start page's are walked; an ASTE in transition is
    waited for and the list restarted.
  - Each installed page of the run is moved to the impure pool when
    unwired in working set 3 or 4, and marked unmodified and stale
    (bit 22 of its disk address).  The ASTE is marked dirty.

  Status stored: none.
}

  procedure ast_$invalidate_no_wait(end_page: integer32);
  var
    start_seg: pinteger;
    seg: pinteger;
    last_in_seg: pinteger;
    first_in_seg: pinteger;
    aste: ast_$aste_ptr_t;
    entry: ast_$pmap_entry_ptr_t;
    ppn: integer32;
    i: integer;
  begin
    start_seg := rshft(start_page, 5);
    seg := rshft(end_page, 5);
    last_in_seg := end_page & 16#1F;
    aste := aote^.aste_list;

    while aste <> nil do begin
      if seg < aste^.segment then
        aste := aste^.next
      else begin
        if aste^.segment < seg then begin
          seg := aste^.segment;
          last_in_seg := 31;
        end;
        first_in_seg := 0;
        if seg < start_seg then
          exit;
        if start_seg = seg then
          first_in_seg := start_page & 16#1F;

        if 15 in aste^.flags then begin
          ast_$wait_for_ast_intrans;
          aste := aote^.aste_list;
        end
        else begin
          if aste^.page_count <> chr(0) then begin
            aste^.flags := aste^.flags + [15];
            aste^.flags := aste^.flags + [14];
            ml_$unlock(ml_$ast_lock);
            ml_$lock(ml_$pmap_lock);
            entry := addr(ast_pmaps[aste^.seg_index, first_in_seg]);
            for i := first_in_seg to last_in_seg do begin
              with entry^ do begin
%if pmmu_page_maps %then
                while ast_$pmap_in_trans in flags do begin
                  mmu_$purge;
                  ast_$wait_for_page_transition;
                end;
%else
                while ast_$pmap_in_trans in flags do
                  ast_$wait_for_page_transition;
%endif
                if ast_$pmap_installed in flags then begin
                  ppn := vpn;
                  with mmap[ppn] do begin
                    if (wsl_index >= 3) and then (wsl_index <= 4)
                       and then (wire_count = 0) then
                      mmap_$impure_transfer(mmap[ppn], ppn);
                    modified := false;
                    disk_addr.aste_dirty := true;
                  end;
%if pmmu_page_maps %then
                  flags := flags - [ast_$pmap_modified];
%else
                  pft[ppn].w_02 := pft[ppn].w_02 & 16#BFFF;
%endif
                end;
              end;
              entry := ast_$pmap_entry_ptr_t(integer32(entry) + 4);
            end;
            aste^.flags := aste^.flags + [13];
%if pmmu_page_maps %then
            mmu_$purge;
%endif
            ml_$unlock(ml_$pmap_lock);
            ml_$lock(ml_$ast_lock);
            aste^.flags := aste^.flags - [15];
            ec_$advance(ast_$ast_in_trans_ec);
          end;

          aste := aste^.next;
          seg := seg - 1;
        end;
      end;
    end;
  end;
