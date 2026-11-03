{ AST_$REMOVE_PAGE - take a page out of its segment's page map.

  Image addresses:
    sau8  0x03C07474  AST_$REMOVE_PAGE
    sau9  0x3C408480  AST_$REMOVE_PAGE

  Assume we're called with the PMAP lock held.

  - The page must be installed in its segment's entry and not wired, or
    the system crashes.
  - The page leaves its working set list; the entry takes the page's
    disk address back, the segment's page count goes down by one, and
    the translations are flushed.

  Status stored: none.
}

procedure ast_$remove_page(ppn: integer32); options(val_param);
var
  seg: pinteger;
  entry: ast_$pmap_entry_ptr_t;
begin
  with mmap[ppn] do begin
    seg := segment;
    entry := addr(ast_pmaps[seg, seg_offset]);
    if not (ast_$pmap_installed in entry^.flags) or else
       (entry^.vpn <> ppn) or else (wire_count <> 0) then
      crash_system(status_$pmap_mismatch);
    mmap_$unavail_remov(ppn, true);
    entry^.flags := entry^.flags -
                    [ast_$pmap_installed, ast_$pmap_resident];
    entry^.vpn := disk_addr.all;
    ast[seg].page_count := pred(ast[seg].page_count);
    mmu_$purge;
  end;
end;
