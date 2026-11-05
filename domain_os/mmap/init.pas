{ MMAP_$INIT - build the memory map at boot.

  Image addresses:
    sau2  0x00E3193E  MMAP_$INIT
    sau4  0x0F835096  MMAP_$INIT
    sau6  0x7803A732  MMAP_$INIT
    sau7  0x3C43A5AE  MMAP_$INIT
    sau8  0x03C34CE6  MMAP_$INIT
    sau9  0x3C437A2A  MMAP_$INIT

  - Every working set list is reset (maximum mmap_$boot_ws_max);
    MMAP_$WS_OWNER is cleared but for entry 1, which gets list 7.
  - Each page of MMAP's range is entered by the memory probe's marks:
    a present page is counted and recorded in DUMP_$ADDRS (more than
    two ranges crash the system).
  - A pageable page goes on the free pool.
  - Lists 5 and 6 are marked in use; list 6 gets a maximum of 100.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure mmap_$init(out table: mmap_$init_table_t);
var
  i: integer;                             { the loops' indices }
  range_count: integer;
  in_range: boolean;
  free_count: linteger;
  vpn: linteger;
  head: linteger;
  tail: linteger;
begin
  for i := 2 to 64 do
    mmap_$ws_owner[i] := 0;
  mmap_$ws_owner[1] := 7;

  for i := 0 to 69 do
    with mmap_$wsl[i] do begin
      flags := flags - [11..15];
      page_count := 0;
      scan_pos := 0;
      max_pages := mmap_$boot_ws_max;
      pri_timestamp := 0;
      ws_timestamp := 0;
      owner := 0;
      ws_floor := 0;
    end;

  for i := 1 to mmap_$table_pages do
    table[i] := 16#FFF;

  range_count := 0;
  in_range := false;
  free_count := 0;
  for vpn := mmap_$first_ppn to mmap_$last_ppn do
    with mmap[vpn]: page do begin
      page.wsl_index := 5;
      if (14 in page.probe) or else (15 in page.probe) then begin
        mmap_$real_pages := mmap_$real_pages + 1;
        if not in_range then begin
          in_range := true;
          range_count := range_count + 1;
          if range_count > 2 then
            crash_system(status_$mmap_examined_max);
          dump_$addrs[range_count].start := vpn * 1024;
        end;
        dump_$addrs[range_count].end_addr := vpn * 1024;
        table[((vpn - mmap_$first_ppn) * 16) div 1024 + 1] := 0;
      end
      else
        in_range := false;

      if 14 in page.probe then begin
        mmap_$pageable_pages := mmap_$pageable_pages + 1;
        if vpn < mmap_$lppn then
          mmap_$lppn := vpn;
        if vpn > mmap_$hppn then
          mmap_$hppn := vpn;
        page.in_wsl := true;
        page.wsl_index := 0;
        if free_count = 0 then begin
          page.prev_vpn := vpn;
          page.next_vpn := vpn;
          mmap_$wsl[0].head_vpn := vpn;
        end
        else begin
          head := mmap_$wsl[0].head_vpn;
          tail := mmap[head].next_vpn;
          page.prev_vpn := head;
          page.next_vpn := tail;
          mmap[head].next_vpn := vpn;
          mmap[tail].prev_vpn := vpn;
        end;
        free_count := free_count + 1;
        page.wire_count := 0;
      end
      else
        page.wire_count := 1;
    end;

  mmap_$wsl[0].page_count := free_count;

  for i := 1 to mmap_$table_pages do
    if table[i] <> 0 then
      table[i] := mmu_$vtop_or_crash((i - 1) * 1024
                                     + integer32(addr(mmap)));

  for i := 1 to range_count do
    dump_$addrs[i].start := dump_$addrs[i].start & 16#FFF80000;

  mmap_$wsl[6].flags := mmap_$wsl[6].flags + [mmap_$wsl_in_use];
  mmap_$wsl[5].flags := mmap_$wsl[5].flags + [mmap_$wsl_in_use];
  mmap_$wsl[6].flags := mmap_$wsl[6].flags + [13];
  mmap_$wsl[6].max_pages := 100;
end;
