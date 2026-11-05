{ mmap_$remove_from_wsl - unlink one page from its working set list.

  Image addresses:
    sau2  0x00E0C6E2  mmap_$remove_from_wsl (module-local)
    sau4  0x0F80CD42  mmap_$remove_from_wsl (module-local)
    sau7  0x3C40E13E  mmap_$remove_from_wsl (module-local)
    sau8  0x03C0D62A  mmap_$remove_from_wsl (module-local)
    sau9  0x3C40E644  mmap_$remove_from_wsl (module-local)

  - The page's neighbors are linked to each other (the head moving to
    its prev_vpn when it is the head) and the page marked on no list.
  - The list's count and MMAP_$PAGEABLE_PAGES go down by one.

  Status stored: none.
}

procedure mmap_$remove_from_wsl(var page: mmap_$mmape_t; vpn: integer32);
  internal;
var
  prev: linteger;
  next_link: linteger;
begin
  with mmap_$wsl[page.wsl_index] do begin
    prev := page.prev_vpn;
    next_link := page.next_vpn;
    mmap[prev].next_vpn := next_link;
    mmap[next_link].prev_vpn := prev;

    if vpn = head_vpn then
      head_vpn := prev;
    page_count := page_count - 1;
    page.in_wsl := false;
    mmap_$pageable_pages := mmap_$pageable_pages - 1;
  end;
end;
