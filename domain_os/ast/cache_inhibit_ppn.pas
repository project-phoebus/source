{ AST_$CACHE_INHIBIT_PPN - stop caching a physical page.

  Image addresses:
    sau7  0x3C408096  AST_$CACHE_INHIBIT_PPN
    sau9  0x3C408896  AST_$CACHE_INHIBIT_PPN

  - Under the PMAP lock: the page's descriptor in its segment's page map
    becomes cache-inhibited and the translations are flushed; a page
    already inhibited crashes the system.

  Status stored: none.
}

procedure ast_$cache_inhibit_ppn(ppn: integer32); options(val_param);
var
  entry: ast_$pmap_entry_ptr_t;
begin
  ml_$lock(ml_$pmap_lock);
  with mmap[ppn] do
    entry := addr(ast_pmaps[segment, seg_offset]);
  if ast_$pmap_cache_inhibit in entry^.flags then
    crash_system(status_$pmap_bad_wire);
  entry^.flags := entry^.flags + [ast_$pmap_cache_inhibit];
  mmu_$purge_tb(2, 0);
  ml_$unlock(ml_$pmap_lock);
end;
