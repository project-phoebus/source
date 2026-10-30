{ MMAP_$FREE_PAGES - put a list of pages on the free pool.

  Image addresses:
    sau2  0x00E0CE56  MMAP_$FREE_PAGES
    sau9  0x3C40EDA4  MMAP_$FREE_PAGES

  - Under the MMAP spin lock each page of the list is unlinked from its
    working set list (none crashes the system, "inconsistent mmape")
    and chained to the others with list index 0.
  - The chain goes into the free pool, whose count goes up.

  Status stored: none.
}

{ TODO(pascal) the frames of the MMAP_ routines against their locals

  Most MMAP_ routines have SAU2 frames that their locals, `with'
  temporaries and result variables explain only in part, and the
  addressed slots' orders follow no one rule.  The declarations follow
  a natural order; no stand-ins are declared.  Settling it needs the
  compiler's frame rules. }

procedure mmap_$free_pages(pid: pinteger;
                           in vpn_array: univ mmap_$vpn_list_t;
                           count: pinteger);
var
  token: pinteger;
  first: linteger;
  last: linteger;
  next_p: linteger;
  prev: linteger;
  i: pinteger;
  vpn: linteger;
  page_next: linteger;
  page_prev: linteger;
  head: linteger;
  tail: linteger;
begin
  with mmap_$wsl[0]: free_pool do begin
    token := ml_$spin_lock(mmap_$lock);

    first := vpn_array[1];
    last := vpn_array[count];
    next_p := first;
    prev := 0;

    for i := 1 to count do begin
      vpn := next_p;
      if i < count then
        next_p := vpn_array[i + 1];
      with mmap[vpn]: page do begin
        if not page.in_wsl then
          crash_system(status_$mmap_inconsistent_mmape);
        with mmap_$wsl[page.wsl_index]: wsl do begin
          page_next := page.next_vpn;
          page_prev := page.prev_vpn;
          mmap[page_prev].next_vpn := page_next;
          mmap[page_next].prev_vpn := page_prev;
          if vpn = wsl.head_vpn then
            wsl.head_vpn := page.prev_vpn;
          wsl.page_count := wsl.page_count - 1;
        end;
        page.prev_vpn := next_p;
        page.next_vpn := prev;
        page.wsl_index := 0;
        page.flags2_7 := false;
        page.modified := false;
      end;
      prev := vpn;
    end;

    if free_pool.page_count = 0 then begin
      mmap[first].next_vpn := last;
      mmap[last].prev_vpn := first;
      free_pool.head_vpn := first;
    end
    else begin
      head := free_pool.head_vpn;
      tail := mmap[head].next_vpn;
      mmap[head].next_vpn := last;
      mmap[tail].prev_vpn := first;
      mmap[first].next_vpn := tail;
      mmap[last].prev_vpn := free_pool.head_vpn;
    end;
    free_pool.page_count := free_pool.page_count + count;

    ml_$spin_unlock(mmap_$lock, token);
  end;
end;
