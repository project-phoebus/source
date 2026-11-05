{ mmap_$add_pages_to_wsl - link a list of pages into a working set list
  as one run.

  Image addresses:
    sau2  0x00E0C5AE  mmap_$add_pages_to_wsl (module-local)
    sau4  0x0F80CC0E  mmap_$add_pages_to_wsl (module-local)
    sau7  0x3C40E01A  mmap_$add_pages_to_wsl (module-local)
    sau8  0x03C0D506  mmap_$add_pages_to_wsl (module-local)
    sau9  0x3C40E4D8  mmap_$add_pages_to_wsl (module-local)

  - Every page of the list is marked on the working set list (priority
    0) and chained to the others in list order; the run goes into the
    list, alone when it is empty, else between the head and the head's
    next page.

  Status stored: none.
}

procedure mmap_$add_pages_to_wsl(in vpn_array: univ mmap_$vpn_list_t;
                                 count: pinteger; wsl_index: integer);
  internal;
var
  n: linteger;
  first: linteger;
  last: linteger;
  i: integer;
  head: linteger;
  tail: linteger;
begin
  n := count;
  first := vpn_array[1];
  last := vpn_array[count];

  with mmap[first]: first_page, mmap[last]: last_page do begin
    first_page.in_wsl := true;
    first_page.wsl_index := wsl_index;
    first_page.priority := 0;

    if count > 1 then begin
      first_page.prev_vpn := vpn_array[2];
      for i := 2 to count - 1 do begin
        mmap[vpn_array[i]].in_wsl := true;
        mmap[vpn_array[i]].wsl_index := wsl_index;
        mmap[vpn_array[i]].prev_vpn := vpn_array[i + 1];
        mmap[vpn_array[i]].priority := 0;
        mmap[vpn_array[i]].next_vpn := vpn_array[i - 1];
      end;
      last_page.in_wsl := true;
      last_page.wsl_index := wsl_index;
      last_page.priority := 0;
      last_page.next_vpn := vpn_array[count - 1];
    end;

    with mmap_$wsl[wsl_index] do begin
      if page_count = 0 then begin
        first_page.next_vpn := last;
        last_page.prev_vpn := first;
        head_vpn := first;
      end
      else begin
        head := head_vpn;
        tail := mmap[head].next_vpn;
        mmap[head].next_vpn := last;
        mmap[tail].prev_vpn := first;
        first_page.next_vpn := tail;
        last_page.prev_vpn := head;
      end;
      page_count := n + page_count;
      mmap_$pageable_pages := mmap_$pageable_pages + n;
    end;
  end;
end;
