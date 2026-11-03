{ MMAP_$SET_WS_MAX - set a working set list's maximum.

  Image addresses:
    sau2  0x00E0CA7A  MMAP_$SET_WS_MAX
    sau8  0x03C0D99C  MMAP_$SET_WS_MAX
    sau9  0x3C40E9D8  MMAP_$SET_WS_MAX

  - The list's max_pages becomes the given maximum.

  Status stored:
    status_$ok: the maximum was set
    status_$mmap_illegal_wsl_index: an index outside 5..69
}

procedure mmap_$set_ws_max(wsl_index: pinteger; max_pages: integer32;
                           out status: status_$t);
begin
  status.all := status_$ok;
  if (wsl_index < 5) or else (wsl_index > 69) then
    status.all := status_$mmap_illegal_wsl_index
  else
    mmap_$wsl[wsl_index].max_pages := max_pages;
end;
