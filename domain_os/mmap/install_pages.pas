{ MMAP_$INSTALL_PAGES - put a list of pages on an address space's
  working set list.

  Image addresses:
    sau2  0x00E0CDF0  MMAP_$INSTALL_PAGES
    sau4  0x0F80D440  MMAP_$INSTALL_PAGES
    sau6  0x7800D5CC  MMAP_$INSTALL_PAGES
    sau7  0x3C40E81C  MMAP_$INSTALL_PAGES
    sau8  0x03C0DD08  MMAP_$INSTALL_PAGES
    sau9  0x3C40ED44  MMAP_$INSTALL_PAGES

  - As MMAP_$INSTALL_LIST with the address space's list,
    MMAP_$WS_OWNER[pid].

  Status stored: none.
}

procedure mmap_$install_pages(in vpn_array: univ mmap_$vpn_list_t;
                              count: pinteger; pid: pinteger);
var
  wsl_index: pinteger;
begin
  wsl_index := mmap_$ws_owner[pid];
  mmap_$add_pages_to_wsl(vpn_array, count, wsl_index);

  with mmap_$wsl[wsl_index] do
    if page_count > max_pages then begin
      mmap_$trim_wsl(wsl_index, page_count - max_pages);
      mmap_$ws_overflow := mmap_$ws_overflow + 1;
    end;
end;
