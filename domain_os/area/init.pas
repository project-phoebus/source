{ AREA_$INIT - set up the area manager's block at boot.

  Image addresses:
    sau2  0x00E2F3A8  AREA_$INIT
    sau4  0x0F832808  AREA_$INIT
    sau6  0x78037C00  AREA_$INIT
    sau7  0x3C437770  AREA_$INIT
    sau9  0x3C434F70  AREA_$INIT

  - The table's maximum is AREAS' size, area_max_entries; the free
    list, the counts, the per-address-space lists, the UID hash buckets
    and the overflow pool are emptied, and the diskless partner's node
    recorded.
  - On a diskless node the three RPMAP pages are wired and mapped at
    AREA_$RPMAP_CACHE (a failure crashes the system).

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure area_$init;
var
  page_va: univ_ptr;
  status: status_$t;
  i: integer;
begin
  area_$format.max_entries := area_max_entries;
  area_$free_list := nil;
  area_$n_areas := 0;
  area_$n_free := 0;
  area_$next_caller_id := 0;

  for i := 0 to 57 do begin
    area_$asid_list[i] := nil;
    area_$seg_table_list[i] := nil;
  end;

  { the hash buckets and the free records }
  for i := 0 to 10 do begin
    area_$uid_hash[i] := nil;
    area_$uid_hash_pool[i].next := addr(area_$uid_hash_pool[i + 1]);
  end;
  area_$uid_hash_pool[10].next := nil;
  area_$uid_hash_free := addr(area_$uid_hash_pool[0]);

  { the partner }
  area_$partner.high := 0;
  if network_$diskless then
    area_$partner.low := network_$mother_node
  else
    area_$partner.low := 0;

  { the RPMAP cache's pages }
  if network_$diskless then
    for i := 1 to 3 do begin
      wp_$calloc(area_$rpmap_page[i], status);
      if status.all <> status_$ok then
        crash_system(status);
      page_va := addr(area_$rpmap_cache[i]);
      mmu_$install(area_$rpmap_page[i], page_va, 0, 16#16);
      with area_$rpmap_slots[i] do begin
        seq := 0;
        volx := 0;
        group := -1;
        dirty := false;
        in_trans := false;
      end;
    end;

  { the overflow pool }
  area_$format.seg_table_count := 0;
  area_$format.seg_table_next := 0;
  for i := 0 to 63 do
    area_$seg_table_pool[i].allocated := false;

  area_$cr_dup := 0;
  area_$del_dup := 0;
end;
