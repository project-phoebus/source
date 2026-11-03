{ MMAP_$ALLOC_PURE - allocate pages from the pure and impure pools.

  Image addresses:
    sau2  0x00E0D78E  MMAP_$ALLOC_PURE
    sau8  0x03C0E648  MMAP_$ALLOC_PURE
    sau9  0x3C40F71A  MMAP_$ALLOC_PURE

  - Pages are taken from pool 1 and then pool 2, up to the count still
    wanted, into the list from its next free element.
  - When too few were found, the current address space's list (if at
    least 384 pages) is trimmed by the count still wanted, once, and
    the pools tried again.  The result is the pages found.

  Status stored: none.
}

function mmap_$alloc_pure(out vpn_array: univ mmap_$vpn_list_t;
                          count: pinteger): pinteger;
label
  10;
var
  allocated: pinteger;
  trimmed: boolean;
  share: linteger;
  wsl_index: pinteger;
  pool: integer;
begin
  mmap_$alloc_cnt := mmap_$alloc_cnt + 1;
  allocated := 0;
  trimmed := false;

  repeat
    for pool := 1 to 2 do
      with mmap_$wsl[pool]: wsl do
        if wsl.page_count <> 0 then begin
          share := min(count, wsl.page_count);
          mmap_$alloc_pages_from_wsl(wsl, vpn_array[allocated + 1], share);
          count := count - share;
          allocated := allocated + share;
          if count = 0 then
            goto 10;
        end;

    if count = 0 then
      goto 10;
    if allocated >= 8 then
      goto 10;
    mmap_$steal_cnt := mmap_$steal_cnt + 1;
    if trimmed then
      goto 10;
    if mmap_$wsl[3].page_count + mmap_$wsl[4].page_count > 8 then
      goto 10;
    wsl_index := mmap_$ws_owner[proc1_$current];
    if mmap_$wsl[wsl_index].page_count < 384 then
      goto 10;
    mmap_$trim_wsl(wsl_index, count);
    trimmed := true;
  until false;

10:
  mmap_$alloc_pages := mmap_$alloc_pages + allocated;
  mmap_$alloc_pure := allocated;
end;
