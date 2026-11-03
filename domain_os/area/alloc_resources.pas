{ area_$alloc_resources - extend the area table by up to count entries.

  Image addresses:
    sau2  0x00E075CA  area_$alloc_resources (module-local)
    sau4  0x0F8078BA  area_$alloc_resources (module-local)
    sau9  0x3C408BFC  area_$alloc_resources (module-local)

  - False when the table (AREAS) is full to AREA_$FORMAT.max_entries;
    else true, with the count clamped to the maximum.
  - Each new entry's first and last bytes get a wired page where there
    is none; the entries are cleared and threaded onto AREA_$FREE_LIST.

  Status stored: none.
}

function area_$alloc_resources(count: pinteger): boolean; internal;
var
  ppn: integer32;
  status: status_$t;
  first: pinteger;
  last: pinteger;
  va: integer32;
  entry: area_$entry_words_ptr_t;
  id: integer;
  k: integer;
begin
  first := area_$n_areas;
  if first >= area_$format.max_entries then
    area_$alloc_resources := false
  else begin
    area_$alloc_resources := true;

    if count + first > area_$format.max_entries then
      count := area_$format.max_entries - first;

    last := count + first;
    first := first + 1;

    { the first entry's page }
    va := integer32(addr(areas[first]));
    discard(mmu_$vtop(va, status));
    if status.all <> status_$ok then begin
      wp_$calloc(ppn, status);
      mmu_$install(ppn, univ_ptr(va), 0, 16#16);
    end;

    { each new entry's last page, and the clear }
    for id := first to last do begin
      entry := area_$entry_words_ptr_t(va);
      va := va + 16#2F;
      discard(mmu_$vtop(va, status));
      if status.all <> status_$ok then begin
        wp_$calloc(ppn, status);
        mmu_$install(ppn, univ_ptr(va), 0, 16#16);
      end;
      for k := 1 to 24 do
        entry^[k] := 0;
      va := va + 1;
    end;

    { the free list's links }
    for id := first to last - 1 do begin
      areas[id].next := addr(areas[id + 1]);
      areas[id].prev := nil;
      areas[id].area_id := id;
    end;

    areas[last].next := area_$free_list;
    areas[last].prev := nil;
    areas[last].area_id := last;
    area_$free_list := addr(areas[first]);
    area_$n_areas := last;
    area_$n_free := area_$n_free + count;
  end;
end;
