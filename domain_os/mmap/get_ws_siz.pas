{ MMAP_$GET_WS_SIZ - report a working set list's sizes.

  Image addresses:
    sau2  0x00E0C9E4  MMAP_$GET_WS_SIZ
    sau4  0x0F80D034  MMAP_$GET_WS_SIZ
    sau8  0x03C0D910  MMAP_$GET_WS_SIZ
    sau9  0x3C40E94C  MMAP_$GET_WS_SIZ

  - The list's page count, its field at 0x14 and its maximum.

  Status stored:
    status_$ok: the sizes were returned
    status_$mmap_illegal_wsl_index: an index above 69
}

procedure mmap_$get_ws_siz(wsl_index: pinteger; out page_count: linteger;
                           out field_14: linteger; out max_pages: linteger;
                           out status: status_$t);
begin
  status.all := status_$ok;
  if wsl_index > 69 then
    status.all := status_$mmap_illegal_wsl_index
  else
    with mmap_$wsl[wsl_index]: wsl do begin
      page_count := wsl.page_count;
      field_14 := wsl.field_14;
      max_pages := wsl.max_pages;
    end;
end;
