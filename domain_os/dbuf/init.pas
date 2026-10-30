{ DBUF_$INIT - build the buffer pool.

  Image addresses:
    sau2  0x00E3ABDA  DBUF_$INIT

  - The pool has sixteen buffers per 1024 pages of real memory, clamped
    to 6..64.  Each entry is linked to its neighbors and given a wired,
    cache-inhibited buffer page (a failure crashes the system), empty.

  Status stored: none.
}

procedure dbuf_$init;
var
  e: dbuf_$entry_ptr_t;
  ppn: integer32;
  status: status_$t;
  i: integer;
begin
  dbuf_$count := rshft(mmap_$real_pages, 10) * 16;
  if dbuf_$count < dbuf_min_buffers then
    dbuf_$count := dbuf_min_buffers
  else if dbuf_$count > dbuf_max_buffers then
    dbuf_$count := dbuf_max_buffers;

  e := addr(dbuf[1]);

  for i := 1 to dbuf_$count do begin
    e^.e_next := dbuf_$entry_ptr_t(integer32(e) + 16#24);
    e^.e_prev := dbuf_$entry_ptr_t(integer32(e) - 16#24);
    e^.e_data := addr(dbuf_blks[i]);
    e^.e_flags.busy := false;
    e^.e_flags.dirty := false;
    e^.e_flags.unused_2 := 0;
    e^.e_flags.vol := 0;
    e^.e_flags.block_type := 0;
    e^.e_ref_count := 0;
    wp_$calloc(ppn, status);
    if status.all <> status_$ok then
      crash_system(status);
    mmu_$install(ppn, addr(dbuf_blks[i]), 0, 16#16);
    mmu_$cache_inhibit_va(addr(dbuf_blks[i]));
    e^.e_ppn := ppn;
    e^.e_block := -1;
    e^.e_ident.uid := uid_$nil;
    e^.e_ident.hint := 0;
    e := e^.e_next;
  end;

  dbuf[1].e_prev := nil;
  dbuf[dbuf_$count].e_next := nil;
  dbuf_$head := addr(dbuf[1]);
  ec_$init(dbuf_$eventcount);
  dbuf_$waiters := 0;
  dbuf_$trouble := [];
end;
