{ MMAP_$FREE - put a page on the free pool.

  Image addresses:
    sau2  0x00E0CAC2  MMAP_$FREE
    sau9  0x3C40EA20  MMAP_$FREE

  - Under the MMAP spin lock the page's flags2_7 bit is cleared and the
    page added to list 0, the free pool, at its tail.

  Status stored: none.
}

procedure mmap_$free(vpn: integer32);
var
  token: pinteger;
begin
  with mmap[vpn]: page do begin
    token := ml_$spin_lock(mmap_$lock);
    page.flags2_7 := false;
    mmap_$add_to_wsl(page, vpn, 0, true);
    ml_$spin_unlock(mmap_$lock, token);
  end;
end;
