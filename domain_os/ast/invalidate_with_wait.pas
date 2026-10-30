{ ast_$invalidate_with_wait - remove an object's installed pages, waiting
  for their transitions.

  Image addresses:
    sau2  0x00E062FA  ast_$invalidate_with_wait (nested)
    sau9  0x3C407586  ast_$invalidate_with_wait (nested)

  Assume we're called with the AST lock held.

  - Nested in AST_$INVALIDATE.  The segments from the end page's down to
    the start page's are walked; each one's ASTE is looked up (created
    for a remote object) and its pages walked under the PMAP lock.
  - An installed page is unmapped, given its disk address back marked
    stale (bit 22), and freed.  The ASTE is marked dirty.

  Returns:
    status_$ok: the pages were removed
    status_$pmap_pages_wired: an installed page is wired
    ast_$lookup_or_create_aste's status: a segment's ASTE failed

  Status stored: none.
}

  function ast_$invalidate_with_wait(end_page: integer32): status_$t;
  label
    10;
  var
    local_status: status_$t;
    page: integer32;
    seg: pinteger;
    last_in_seg: pinteger;
    aste: ast_$aste_ptr_t;
    entry: ast_$pmap_entry_ptr_t;
    ppn: integer32;
    i: integer;
    unused_20: array[1..3] of integer;    { a stand-in (TODO(pascal)
                                            below) }
    first_in_seg: pinteger;
  begin
    local_status.all := status_$ok;
    page := end_page;
    seg := rshft(page, 5);
    last_in_seg := page & 16#1F;

    repeat
      aste := ast_$lookup_aste(aote^, seg);
      if (aste = nil) and then is_remote then begin
        aste := ast_$lookup_or_create_aste(aote^, seg, local_status);
        if aste = nil then
          goto 10;
      end;

      page := page - last_in_seg;
      if page < integer32(start_page) then
        page := integer32(start_page);

      if aste <> nil then begin
        aste^.flags := aste^.flags + [15];
        aste^.flags := aste^.flags + [14];
        ml_$unlock(ml_$ast_lock);
        ml_$lock(ml_$pmap_lock);
        entry := addr(ast_pmaps[aste^.seg_index, last_in_seg]);
        scratch := 0;
        first_in_seg := page & 16#1F;
        for i := first_in_seg to last_in_seg do begin
%if pmmu_page_maps %then
          while ast_$pmap_in_trans in entry^.flags do begin
            mmu_$purge;
            ast_$wait_for_page_transition;
          end;
          if ast_$pmap_installed in entry^.flags then begin
            ppn := entry^.vpn;
            if mmap[ppn].wire_count <> 0 then begin
              local_status.all := status_$pmap_pages_wired;
              exit;
            end;
            entry^.flags := entry^.flags - [ast_$pmap_resident];
            entry^.flags := entry^.flags - [ast_$pmap_installed];
            entry^.vpn := mmap[ppn].disk_addr.all;
            entry^.hi_flags := entry^.hi_flags + [15];
            mmap_$free_remove(mmap[ppn], ppn);
            aste^.page_count := pred(aste^.page_count);
          end
          else if entry^.dentry.daddr <> 0 then
            entry^.hi_flags := entry^.hi_flags + [15];
          entry := ast_$pmap_entry_ptr_t(integer32(entry) - 4);
        end;
        aste^.flags := aste^.flags + [13];
        { the translations of the pages invalidated flushed }
        mmu_$purge;
%else
          while ast_$pmap_in_trans in entry^.flags do
            ast_$wait_for_page_transition;
          if ast_$pmap_installed in entry^.flags then begin
            ppn := entry^.vpn;
            if mmap[ppn].wire_count <> 0 then begin
              local_status.all := status_$pmap_pages_wired;
              exit;
            end;
            if ast_$pmap_resident in entry^.flags then begin
              entry^.flags := entry^.flags - [ast_$pmap_resident];
              mmu_$remove(ppn);
            end;
            entry^.flags := entry^.flags - [ast_$pmap_installed];
            entry^.all := entry^.all & 16#FF800000;
            entry^.all := entry^.all ! mmap[ppn].disk_addr.all;
            entry^.flags := entry^.flags + [6];
            mmap_$free_remove(mmap[ppn], ppn);
            aste^.page_count := pred(aste^.page_count);
          end
          else if entry^.dentry.daddr <> 0 then
            entry^.flags := entry^.flags + [6];
          entry := ast_$pmap_entry_ptr_t(integer32(entry) - 4);
        end;
        aste^.flags := aste^.flags + [13];
%endif
        ml_$unlock(ml_$pmap_lock);
        ml_$lock(ml_$ast_lock);
        aste^.flags := aste^.flags - [15];
        ec_$advance(ast_$ast_in_trans_ec);
        if local_status.all <> status_$ok then
          goto 10;
      end;

      if linteger(page) <= start_page then
        goto 10;
      page := page - 1;
      last_in_seg := 31;
      seg := seg - 1;
    until false;

  10:
    ast_$invalidate_with_wait := local_status;
  end;

{ TODO(pascal) ast_$invalidate_with_wait's frame: the 6-byte stand-in
  unused_20 puts first_in_seg where the SAU2 image has it; what the original
  declared there (more register-held locals' homes, or a wider type for seg
  or i) is not known. }

{ TODO(pascal) ast_$invalidate_with_wait's page: the SAU2 image compares
  it with the parent's start_page both signed and unsigned; written with
  type transfers of one or the other, which may not be the original's
  construct (AST_$RESERVE has the same pair). }
