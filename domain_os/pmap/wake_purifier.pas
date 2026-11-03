{ PMAP_$WAKE_PURIFIER - wake the purifiers, and wait for pages if asked.

  Image addresses:
    sau2  0x00E13A18  PMAP_$WAKE_PURIFIER
    sau4  0x0F8142FA  PMAP_$WAKE_PURIFIER
    sau9  0x3C415D50  PMAP_$WAKE_PURIFIER

  Assume we're called with the PMAP lock held.

  - The remote purifier is woken only when list 4 (the remote pool) has
    pages.
  - With wait set, waits for the next advance of PMAP_$PAGES_EC with the
    lock released, and returns with it held again.

  Status stored: none.
}

procedure pmap_$wake_purifier(wait: boolean);
var
  wait_val: integer32;
begin
  wait_val := pmap_$pages_ec.value + 1;
  ec_$advance(pmap_$l_purifier_ec);
  if mmap_$wsl[4].page_count <> 0 then
    ec_$advance(pmap_$r_purifier_ec);
  if wait then begin
    ml_$unlock(ml_$pmap_lock);
    discard(ec_$waitn(addr(pmap_$pages_ec), wait_val, 1));
    ml_$lock(ml_$pmap_lock);
  end;
end;
