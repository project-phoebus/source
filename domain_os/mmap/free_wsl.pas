{ MMAP_$FREE_WSL - release an address space's working set list.

  Image addresses:
    sau2  0x00E0D158  MMAP_$FREE_WSL
    sau4  0x0F80D7C8  MMAP_$FREE_WSL
    sau6  0x7800D934  MMAP_$FREE_WSL
    sau7  0x3C40EB82  MMAP_$FREE_WSL
    sau8  0x03C0E06E  MMAP_$FREE_WSL
    sau9  0x3C40F0BE  MMAP_$FREE_WSL

  - An address space above 64 crashes the system ("illegal pid").  Its
    entry of MMAP_$WS_OWNER is cleared; a list no other address space
    owns is purged and marked no longer in use.
  - pid 0's entry is MMAP_$WSL_HI_MARK.

  Status stored: none.
}

procedure mmap_$free_wsl(pid: pinteger);
var
  wsl_index: pinteger;
  i: integer;
begin
  if pid > 64 then
    crash_system(status_$mmap_illegal_pid);

  wsl_index := mmap_$ws_owner[pid];
  mmap_$ws_owner[pid] := 0;

  for i := 1 to 64 do
    if mmap_$ws_owner[i] = wsl_index then
      return;

  mmap_$purge(wsl_index);
  mmap_$wsl[wsl_index].flags :=
    mmap_$wsl[wsl_index].flags - [mmap_$wsl_in_use];
end;
