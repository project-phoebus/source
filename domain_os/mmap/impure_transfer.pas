{ MMAP_$IMPURE_TRANSFER - move a dirty page to the pure pool.

  Image addresses:
    sau2  0x00E0CBE8  MMAP_$IMPURE_TRANSFER
    sau4  0x0F80D238  MMAP_$IMPURE_TRANSFER
    sau6  0x7800D3CC  MMAP_$IMPURE_TRANSFER
    sau7  0x3C40E61C  MMAP_$IMPURE_TRANSFER
    sau8  0x03C0DB08  MMAP_$IMPURE_TRANSFER
    sau9  0x3C40EB44  MMAP_$IMPURE_TRANSFER

  - A page on pool 3 or 4 (the dirty pools) is taken off it and added
    to pool 1, not at its tail.

  Status stored: none.
}

procedure mmap_$impure_transfer(var page: mmap_$mmape_t; vpn: integer32);
begin
  if (page.wsl_index = 4) or else (page.wsl_index = 3) then begin
    mmap_$remove_from_wsl(page, vpn);
    mmap_$add_to_wsl(page, vpn, 1, false);
  end;
end;
