{ MMAP_$SET_WS_INDEX - give an address space a working set list.

  Image addresses:
    sau2  0x00E0D1C8  MMAP_$SET_WS_INDEX
    sau9  0x3C40F128  MMAP_$SET_WS_INDEX

  - Index 0 takes the first list from 8 to 69 not in use (raising
    MMAP_$WSL_HI_MARK); another must lie in 5..MMAP_$WSL_HI_MARK.  The
    list is marked in use and becomes the address space's.
  - A bad address space or index, or no free list, crashes the system.
  - pid 0's entry is MMAP_$WSL_HI_MARK.

  Status stored: none.
}

procedure mmap_$set_ws_index(pid: pinteger; in out wsl_index: pinteger);
var
  i: pinteger;
begin
  if pid > 64 then
    crash_system(status_$mmap_illegal_pid);

  if wsl_index = 0 then begin
    for i := 8 to 69 do
      if not (mmap_$wsl_in_use in mmap_$wsl[i].flags) then begin
        wsl_index := i;
        if i > mmap_$wsl_hi_mark then
          mmap_$wsl_hi_mark := i;
        exit;
      end;
  end
  else if (wsl_index < 5) or else (wsl_index > mmap_$wsl_hi_mark) then
    crash_system(status_$mmap_illegal_wsl_index);

  if wsl_index = 0 then
    crash_system(status_$mmap_ws_lists_exhausted)
  else begin
    mmap_$wsl[wsl_index].flags :=
      mmap_$wsl[wsl_index].flags + [mmap_$wsl_in_use];
    mmap_$ws_owner[pid] := wsl_index;
  end;
end;
