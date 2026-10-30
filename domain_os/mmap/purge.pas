{ MMAP_$PURGE - empty a working set list.

  Image addresses:
    sau2  0x00E0D11C  MMAP_$PURGE
    sau9  0x3C40F082  MMAP_$PURGE

  - An index above MMAP_$WSL_HI_MARK crashes the system ("illegal wsl
    index"); otherwise the list is trimmed with the purge count
    16#3FFFFF, which takes every page.

  Status stored: none.
}

procedure mmap_$purge(wsl_index: pinteger);
begin
  if wsl_index > mmap_$wsl_hi_mark then
    crash_system(status_$mmap_illegal_wsl_index);
  mmap_$trim_wsl(wsl_index, 16#3FFFFF);
end;
