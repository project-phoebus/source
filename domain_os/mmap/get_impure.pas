{ MMAP_$GET_IMPURE - take impure pages off a list for the purifier.

  Image addresses:
    sau2  0x00E0D5EA  MMAP_$GET_IMPURE
    sau4  0x0F80DC3A  MMAP_$GET_IMPURE
    sau6  0x7800DD7A  MMAP_$GET_IMPURE
    sau7  0x3C40EFC0  MMAP_$GET_IMPURE
    sau8  0x03C0E4AC  MMAP_$GET_IMPURE
    sau9  0x3C40F554  MMAP_$GET_IMPURE

  - From the list's head along prev_vpn, up to max_pages pages are
    taken, at most 100 examined (all with all_pages).
  - A page qualifies with all_pages, or with flags2_7 clear and its
    object's attribute bit 12 set.
  - A page taken is unlinked, marked off the list and its modified bit
    cleared; the list's count, its head and MMAP_$PAGEABLE_PAGES follow.

  Status stored: none.
}

procedure mmap_$get_impure(wsl_index: pinteger;
                           out vpn_array: univ mmap_$vpn_list_t;
                           all_pages: boolean; max_pages: pinteger;
                           out scanned: linteger; out returned: pinteger);
var
  vpn: linteger;
  next_p: linteger;
  n_returned: pinteger;
  n_scanned: linteger;
  take: boolean;
  max_scan: linteger;
  prev_v: linteger;
  nv: linteger;
begin
  with mmap_$wsl[wsl_index]: wsl do begin
    vpn := wsl.head_vpn;
    n_scanned := 0;
    n_returned := 0;
    if all_pages then
      max_scan := wsl.page_count
    else
      max_scan := min(100, wsl.page_count);

    while (n_returned < max_pages) and then (n_scanned < max_scan) do begin
      with mmap[vpn]: page do begin
        take := all_pages;
        prev_v := page.prev_vpn;
        next_p := prev_v;
        if not page.flags2_7
           and then ((ast[page.segment].aote^.attr_flags & 16#1000) <> 0)
        then
          take := true;
        if take then begin
          n_returned := n_returned + 1;
          vpn_array[n_returned] := vpn;
          nv := page.next_vpn;
          mmap[prev_v].next_vpn := nv;
          mmap[nv].prev_vpn := prev_v;
          page.in_wsl := false;
          page.modified := false;
        end;
      end;
      n_scanned := n_scanned + 1;
      vpn := next_p;
    end;

    wsl.page_count := wsl.page_count - n_returned;
    if wsl.page_count <> 0 then
      wsl.head_vpn := vpn;
  end;

  returned := n_returned;
  scanned := n_scanned;
  mmap_$pageable_pages := mmap_$pageable_pages - n_returned;
end;
