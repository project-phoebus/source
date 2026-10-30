{ area_$alloc_seg_table - take an overflow segment table from the pool.

  Image addresses:
    sau2  0x00E09D2E  area_$alloc_seg_table (module-local)
    sau9  0x3C40B7F2  area_$alloc_seg_table (module-local)

  - Under the AST lock the record at the pool's search cursor gets a
    fresh wired page at its page of PIT_PAGES, is marked allocated and
    pushed on its address space's list.
  - The page is cleared after the lock.
  - The result is the record, nil when all 64 are in use.

  Status stored: none.
}

function area_$alloc_seg_table(asid: integer; area_id: integer;
                               table_index: integer): area_$seg_table_ptr_t;
  internal;
var
  st: status_$t;
  ppn: integer32;
  page: area_$page_longs_ptr_t;
  rec: area_$seg_table_ptr_t;
  idx: integer;
  i: integer;
begin
  area_$alloc_seg_table := nil;
  ml_$lock(ml_$ast_lock);
  if area_$format.seg_table_count >= 64 then begin
    ml_$unlock(ml_$ast_lock);
    return;
  end;

  { wire the cursor's page }
  page := addr(pit_pages[area_$format.seg_table_next]);
  wp_$calloc(ppn, st);
  mmu_$install(ppn, page, 0, 16#16);

  { take the cursor's record }
  area_$format.seg_table_count := area_$format.seg_table_count + 1;
  rec := addr(area_$seg_table_pool[area_$format.seg_table_next]);
  rec^.allocated := true;
  area_$alloc_seg_table := rec;

  { the next free record above it }
  if area_$format.seg_table_count < 64 then begin
    for idx := area_$format.seg_table_next + 1 to 63 do
      if not area_$seg_table_pool[idx].allocated then begin
        area_$format.seg_table_next := idx;
        exit;
      end;
  end
  else
    area_$format.seg_table_next := 64;

  { fill it and push it on the list }
  rec^.bitmap := page;
  rec^.area_id := area_id;
  rec^.table_index := table_index;
  rec^.next := area_$seg_table_list[asid];
  area_$seg_table_list[asid] := rec;

  ml_$unlock(ml_$ast_lock);
  for i := 0 to 255 do
    page^[i] := 0;
end;
