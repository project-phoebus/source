{ disk_$grow_qblk_pool - add pages to the disk's queue-block pool.

  Image addresses:
    sau2  0x00E3BC40  disk_$grow_qblk_pool

  Assume we're called with the queue blocks' lock held.

  - Enough pages (sixteen blocks each, sixteen pages at most in all) are
    added for count free blocks, at least 33 without a reserve block;
    with none left the pool's growth is disabled.
  - With the lock released each page gets a wired, cache-inhibited
    physical page (a failure crashes the system); then its blocks are
    chained onto the free list.
  - The result is whether the free blocks reach the number wanted.
  - The free head is set whether or not a page was added; each page's
    last block is linked twice.

  Status stored: none.
}

function disk_$grow_qblk_pool(count: pinteger): boolean;
  internal;
label
  10;
var
  n: pinteger;
  diff: integer32;
  ppns: array[1..16] of integer32;
  status: status_$t;
  ppn: integer32;
  last: integer;
  first: integer;
  pages: pinteger;
  avail: integer32;
  want: integer32;
  page: integer;
  k: integer;
  base: integer32;
begin
  if disk_$reserve_block = nil then
    n := max(16#21, count)
  else
    n := count;

  avail := disk_$nfblks;
  want := n;
  diff := want - avail;
  pages := diff div 16;
  if diff mod 16 <> 0 then
    pages := pages + 1;

  if disk_$pages_alloc + pages > 16 then begin
    pages := 16 - disk_$pages_alloc;
    if pages = 0 then begin
      disk_$alloc_disabled := true;
      goto 10;
    end;
  end;

  first := disk_$pages_alloc + 1;
  disk_$pages_alloc := disk_$pages_alloc + pages;
  last := disk_$pages_alloc;
  ml_$exclusion_stop(disk_$exclusion);

  { the new pages, the lock released }
  for page := first to last do begin
    wp_$calloc(ppn, status);
    if status.all <> status_$ok then
      crash_system(status);
    mmu_$install(ppn, addr(disk_blk_pool[page]), 0, 16#16);
    mmu_$cache_inhibit_va(addr(disk_blk_pool[page]));
    ppns[page] := ppn;
  end;

  ml_$exclusion_start(disk_$exclusion);

  { their blocks }
  for page := first to last do begin
    base := lshft(ppns[page], 10);
    for k := 1 to 16 do begin
      disk_blk_pool[page][k].free_next := addr(disk_blk_pool[page][k + 1]);
      disk_blk_pool[page][k].phys :=
        (integer32(addr(disk_blk_pool[page][k].header)) & 16#3FF) + base;
    end;
    if page < last then
      disk_blk_pool[page][16].free_next := addr(disk_blk_pool[page + 1])
    else
      disk_blk_pool[page][16].free_next := disk_$free_head;
  end;

  disk_$free_head := addr(disk_blk_pool[first]);
  disk_$nfblks := disk_$nfblks + pages * 16;

  { the reserve block }
  if disk_$reserve_block = nil then begin
    disk_$reserve_block := disk_$free_head;
    disk_$free_head := disk_$free_head^.free_next;
    disk_$reserve_block^.free_next := nil;
    disk_$reserve_block^.next := nil;
    disk_$reserve_avail := true;
    disk_$nfblks := disk_$nfblks - 1;
  end;

10:
  disk_$grow_qblk_pool := disk_$nfblks >= want;
end;
