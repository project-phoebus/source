{ MMAP_$UNAVAIL_REMOV - take a page off its working set list.

  Image addresses:
    sau2  0x00E0CC30  MMAP_$UNAVAIL_REMOV
    sau9  0x3C40EB8C  MMAP_$UNAVAIL_REMOV

  - The page is taken off its list; the second argument is not read.

  Status stored: none.
}

procedure mmap_$unavail_remov(vpn: integer32; unused_flag: boolean);
begin
  with mmap[vpn]: page do
    mmap_$remove_from_wsl(page, vpn);
end;
