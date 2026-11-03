{ MMAP_$FREE_REMOVE - take a page off its list and put it on the free
  pool.

  Image addresses:
    sau2  0x00E0CB86  MMAP_$FREE_REMOVE
    sau8  0x03C0DAA6  MMAP_$FREE_REMOVE
    sau9  0x3C40EAE2  MMAP_$FREE_REMOVE

  - A page on a list is taken off it; then, under the MMAP spin lock,
    its flags2_7 bit is cleared and it goes on list 0 at its tail.
  - The removal from the old list is done before the lock is taken.

  Status stored: none.
}

procedure mmap_$free_remove(var page: mmap_$mmape_t; vpn: integer32);
var
  token: pinteger;
begin
  if page.in_wsl then
    mmap_$remove_from_wsl(page, vpn);
  token := ml_$spin_lock(mmap_$lock);
  page.flags2_7 := false;
  mmap_$add_to_wsl(page, vpn, 0, true);
  ml_$spin_unlock(mmap_$lock, token);
end;
