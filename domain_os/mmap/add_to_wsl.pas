{ mmap_$add_to_wsl - link one page into a working set list.

  Image addresses:
    sau2  0x00E0C514  mmap_$add_to_wsl (module-local)
    sau8  0x03C0D474  mmap_$add_to_wsl (module-local)
    sau9  0x3C40E42C  mmap_$add_to_wsl (module-local)

  - The page is marked on the list (priority 0) and linked in: alone on
    an empty list, else between the head and the head's next page;
    unless it goes at the tail it becomes the head.
  - The list's count and MMAP_$PAGEABLE_PAGES go up by one.

  Status stored: none.
}

procedure mmap_$add_to_wsl(var page: mmap_$mmape_t; vpn: integer32;
                           wsl_index: integer; at_tail: boolean);
  internal;
var
  head: linteger;
  tail: linteger;
begin
  with mmap_$wsl[wsl_index] do begin
    page.in_wsl := true;
    page.wsl_index := wsl_index;
    page.priority := 0;

    if page_count = 0 then begin
      page.prev_vpn := vpn;
      page.next_vpn := vpn;
      head_vpn := vpn;
    end
    else begin
      head := head_vpn;
      tail := mmap[head].next_vpn;
      mmap[head].next_vpn := vpn;
      page.prev_vpn := head;
      page.next_vpn := tail;
      mmap[tail].prev_vpn := vpn;
      if not at_tail then
        head_vpn := vpn;
    end;

    page_count := page_count + 1;
    mmap_$pageable_pages := mmap_$pageable_pages + 1;
  end;
end;
