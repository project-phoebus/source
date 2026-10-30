{ mmap_$alloc_pages_from_wsl - take pages off the head of a working set
  list.

  Image addresses:
    sau2  0x00E0D6F8  mmap_$alloc_pages_from_wsl (module-local)
    sau9  0x3C40F672  mmap_$alloc_pages_from_wsl (module-local)

  - From the list's head along prev_vpn, count pages go into the list
    given, each marked off the list; the pages left are relinked around
    the run and the head moves to the first of them.
  - The list's count and MMAP_$PAGEABLE_PAGES drop by count.

  Status stored: none.
}

procedure mmap_$alloc_pages_from_wsl(var wsl: mmap_$ws_hdr_t;
                                     out vpn_array: univ mmap_$vpn_list_t;
                                     count: pinteger);
  internal;
var
  first: linteger;
  current: linteger;
  i: pinteger;
  n: linteger;
  tail: linteger;
begin
  first := wsl.head_vpn;
  current := first;

  for i := 1 to count do begin
    vpn_array[i] := current;
    with mmap[current] do begin
      in_wsl := false;
      current := prev_vpn;
    end;
  end;

  n := count;
  wsl.page_count := wsl.page_count - n;
  if wsl.page_count <> 0 then begin
    tail := mmap[first].next_vpn;
    mmap[tail].prev_vpn := current;
    mmap[current].next_vpn := tail;
    wsl.head_vpn := current;
  end;

  mmap_$pageable_pages := mmap_$pageable_pages - n;
end;
