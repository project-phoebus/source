{ AST_$CACHE_ENABLE_PPN - resume caching a physical page.

  Image addresses:
    sau9  0x3C408926  AST_$CACHE_ENABLE_PPN

  - Under the PMAP lock: the page's descriptor in its segment's page map
    stops being cache-inhibited; a page not inhibited crashes the system.
    The translations are not flushed.

  Status stored: none.
}

procedure ast_$cache_enable_ppn(ppn: integer32); options(val_param);
var
  entry: ast_$pmap_entry_ptr_t;
begin
  ml_$lock(ml_$pmap_lock);
  with mmap[ppn] do
    entry := addr(ast_pmaps[segment, seg_offset]);
  if not (ast_$pmap_cache_inhibit in entry^.flags) then
    crash_system(status_$pmap_bad_unwire);
  entry^.flags := entry^.flags - [ast_$pmap_cache_inhibit];
  ml_$unlock(ml_$pmap_lock);
end;
