{ MMAP_$AVAIL - put a page back on its working set list.

  Image addresses:
    sau2  0x00E0CC64  MMAP_$AVAIL
    sau8  0x03C0DB84  MMAP_$AVAIL
    sau9  0x3C40EBC0  MMAP_$AVAIL

  - A list index above 69 in the page's entry crashes the system ("bad
    avail"); otherwise the page goes on the list its entry names, at
    its tail.

  Status stored: none.
}

procedure mmap_$avail(vpn: integer32);
begin
  with mmap[vpn]: page do begin
    if page.wsl_index > 69 then
      crash_system(status_$mmap_bad_avail);
    mmap_$add_to_wsl(page, vpn, page.wsl_index, true);
  end;
end;
