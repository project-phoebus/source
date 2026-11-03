{ MMAP_$INSTALL_LIST - put a list of pages on a working set list.

  Image addresses:
    sau2  0x00E0CD80  MMAP_$INSTALL_LIST
    sau8  0x03C0DC9C  MMAP_$INSTALL_LIST
    sau9  0x3C40ECD8  MMAP_$INSTALL_LIST

  - The list is the wired pool (5) when asked, else the current address
    space's; the pages go on it as one run.  A list then over its
    maximum is trimmed by the excess (MMAP_$WS_OVERFLOW counts it).

  Status stored: none.
}

procedure mmap_$install_list(in vpn_array: univ mmap_$vpn_list_t;
                             count: pinteger; use_wired: boolean);
var
  wsl_index: pinteger;
begin
  if use_wired then
    wsl_index := 5
  else
    wsl_index := mmap_$ws_owner[proc1_$current];

  mmap_$add_pages_to_wsl(vpn_array, count, wsl_index);

  with mmap_$wsl[wsl_index] do
    if page_count > max_pages then begin
      mmap_$trim_wsl(wsl_index, page_count - max_pages);
      mmap_$ws_overflow := mmap_$ws_overflow + 1;
    end;
end;
