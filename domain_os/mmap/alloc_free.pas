{ MMAP_$ALLOC_FREE - allocate pages from the free pool.

  Image addresses:
    sau2  0x00E0D870  MMAP_$ALLOC_FREE
    sau8  0x03C0E722  MMAP_$ALLOC_FREE
    sau9  0x3C40F7F6  MMAP_$ALLOC_FREE

  - Under the MMAP spin lock as many pages as asked for, up to the free
    pool's size, are taken into the list; the result is the pages
    taken (0 for an empty pool).
  - After the unlock MMAP_$ALLOC_CNT and MMAP_$ALLOC_PAGES go up.

  Status stored: none.
}

function mmap_$alloc_free(out vpn_array: univ mmap_$vpn_list_t;
                          count: pinteger): pinteger;
var
  token: pinteger;
  to_alloc: pinteger;
begin
  token := ml_$spin_lock(mmap_$lock);

  if mmap_$wsl[0].page_count = 0 then begin
    ml_$spin_unlock(mmap_$lock, token);
    mmap_$alloc_free := 0;
    return;
  end;

  to_alloc := min(count, mmap_$wsl[0].page_count);
  mmap_$alloc_pages_from_wsl(mmap_$wsl[0], vpn_array, to_alloc);

  ml_$spin_unlock(mmap_$lock, token);

  mmap_$alloc_cnt := mmap_$alloc_cnt + 1;
  mmap_$alloc_pages := mmap_$alloc_pages + to_alloc;
  mmap_$alloc_free := to_alloc;
end;
