{ MMAP_$FREE_LIST - put a chain of pages on the free pool.

  Image addresses:
    sau2  0x00E0CB20  MMAP_$FREE_LIST
    sau4  0x0F80D170  MMAP_$FREE_LIST
    sau8  0x03C0DA42  MMAP_$FREE_LIST
    sau9  0x3C40EA7E  MMAP_$FREE_LIST

  - Under the MMAP spin lock each page of the chain (from the given page
    through next_vpn, 0 ending it) goes on list 0, the free pool, at
    its tail.

  Status stored: none.
}

procedure mmap_$free_list(vpn: integer32);
var
  current: linteger;
  next_link: linteger;
  token: pinteger;
begin
  token := ml_$spin_lock(mmap_$lock);

  current := vpn;
  while current <> 0 do begin
    with mmap[current]: page do begin
      next_link := page.next_vpn;
      mmap_$add_to_wsl(page, current, 0, true);
    end;
    current := next_link;
  end;

  ml_$spin_unlock(mmap_$lock, token);
end;
