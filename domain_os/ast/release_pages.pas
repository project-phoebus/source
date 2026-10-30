{ AST_$RELEASE_PAGES - unwire a segment's pages.

  Image addresses:
    sau2  0x00E06F88  AST_$RELEASE_PAGES
    sau9  0x3C4081DA  AST_$RELEASE_PAGES

  - Under the PMAP lock each of the segment's 32 installed and wired
    entries loses its wired member.  A page with no wirings left is
    collected, any other removed from the MMU at once.
  - The collected pages are removed in one MMU_$REMOVE_LIST and, with
    return_to_pool, handed to MMAP_$RELEASE_PAGES.
  - TODO(pascal): 4 frame bytes no object explains (the stand-in
    unused_90).

  Status stored: none.
}

procedure ast_$release_pages(aste: ast_$aste_ptr_t;
                             return_to_pool: boolean);
var
  list: ast_$ppn_list_t;
  count: pinteger;
  i: integer;
  ppn: integer32;
  entry: ast_$pmap_entry_ptr_t;
  unused_90: integer32;                   { see the TODO above }
begin
  count := 0;
  entry := addr(ast_pmaps[aste^.seg_index][0]);
  ml_$lock(ml_$pmap_lock);

%if pmmu_page_maps %then
  for i := 0 to 31 do begin
    if (ast_$pmap_installed in entry^.flags) and then
       (ast_$pmap_resident in entry^.flags) then begin
      ppn := entry^.vpn;
      { a wired page stays resident }
      if mmap[ppn].wire_count = 0 then begin
        entry^.flags := entry^.flags - [ast_$pmap_resident];
        count := count + 1;
        list[count] := ppn;
      end;
    end;
    entry := ast_$pmap_entry_ptr_t(integer32(entry) + 4);
  end;

  { the translations are flushed only when the pages go back to the
    pool }
  if count <> 0 then
    if return_to_pool then begin
      mmu_$purge;
      mmap_$release_pages(proc1_$current, list, count);
    end;
%else
  for i := 0 to 31 do begin
    if (ast_$pmap_installed in entry^.flags) and then
       (ast_$pmap_resident in entry^.flags) then begin
      ppn := entry^.vpn;
      if mmap[ppn].wire_count = 0 then begin
        entry^.flags := entry^.flags - [ast_$pmap_resident];
        count := count + 1;
        list[count] := ppn;
      end
      else begin
        entry^.flags := entry^.flags - [ast_$pmap_resident];
        mmu_$remove(ppn);
      end;
    end;
    entry := ast_$pmap_entry_ptr_t(integer32(entry) + 4);
  end;

  if count <> 0 then begin
    mmu_$remove_list(list, count);
    if return_to_pool then
      mmap_$release_pages(proc1_$current, list, count);
  end;

%endif

  ml_$unlock(ml_$pmap_lock);
end;
