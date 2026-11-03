{ AST_$INVALIDATE_PAGE - drop one installed page from a segment's page
  map.

  Image addresses:
    sau2  0x00E00F16  AST_$INVALIDATE_PAGE
    sau8  0x03C012FC  AST_$INVALIDATE_PAGE
    sau9  0x3C4022FC  AST_$INVALIDATE_PAGE

  - A page mapped in the MMU is unmapped; the entry loses its installed member and takes the page's
    disk address back.
  - The frame goes back to MMAP_$FREE_REMOVE and the segment's page
    count goes down by one.

  Status stored: none.
}

procedure ast_$invalidate_page(var aste: ast_$aste_t;
                               var entry: ast_$pmap_entry_t;
                               vpn: integer32);
  options(val_param);
begin
  with mmap[vpn] do begin
%if pmmu_page_maps %then
    { a resident descriptor is made invalid, and the translations
      flushed }
    if odd(entry.low) then begin
      entry.flags := entry.flags - [ast_$pmap_resident];
      mmu_$purge;
    end;

    entry.flags := entry.flags - [ast_$pmap_installed];
    entry.vpn := disk_addr.all;
%else
    if ast_$pmap_resident in entry.flags then begin
      entry.flags := entry.flags - [ast_$pmap_resident];
      mmu_$remove(vpn);
    end;

    entry.flags := entry.flags - [ast_$pmap_installed];
    entry.all := entry.all & 16#FF800000;
    entry.all := entry.all ! disk_addr.all;
%endif

    mmap_$free_remove(mmap[vpn], vpn);
  end;

  aste.page_count := pred(aste.page_count);
end;
