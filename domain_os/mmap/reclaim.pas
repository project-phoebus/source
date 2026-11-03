{ MMAP_$RECLAIM - take pages back from the global pools.

  Image addresses:
    sau2  0x00E0D914  MMAP_$RECLAIM
    sau4  0x0F80DF68  MMAP_$RECLAIM
    sau8  0x03C0E91E  MMAP_$RECLAIM
    sau9  0x3C40F9F8  MMAP_$RECLAIM

  - The list is the wired pool (5) when asked, else the current address
    space's.  Each page of the list on pools 0..4 is taken off and
    added to it at its tail; one on pool 0 (free) crashes the system.
  - A list then over its maximum is trimmed by the excess.

  Status stored: none.
}

procedure mmap_$reclaim(in vpn_array: univ mmap_$vpn_list_t;
                        count: pinteger; use_wired: boolean);
var
  wsl_index: pinteger;
  reclaimed: boolean;
  i: pinteger;
  vpn: linteger;
begin
  if use_wired then
    wsl_index := 5
  else
    wsl_index := mmap_$ws_owner[proc1_$current];
  reclaimed := false;

  for i := 1 to count do begin
    vpn := vpn_array[i];
    with mmap[vpn]: page do begin
      if page.wsl_index > 4 then
        next;
      if not page.in_wsl then
        next;
      if page.wsl_index = 0 then
        crash_system(status_$mmap_bad_reclaim);
      mmap_$remove_from_wsl(page, vpn);
      mmap_$add_to_wsl(page, vpn, wsl_index, true);
      reclaimed := true;
    end;
  end;

  if reclaimed then
    with mmap_$wsl[wsl_index] do
      if page_count > max_pages then begin
        mmap_$trim_wsl(wsl_index, page_count - max_pages);
        mmap_$ws_overflow := mmap_$ws_overflow + 1;
      end;
end;
