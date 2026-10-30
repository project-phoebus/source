{ MMAP_$SET_WS_PRI - stamp the current process's working set with the
  time.

  Image addresses:
    sau2  0x00E0C98A  MMAP_$SET_WS_PRI
    sau9  0x3C40E8F4  MMAP_$SET_WS_PRI

  - The current address space's list gets TIME_$CLOCKH as its
    pri_timestamp; index 0 (no list) is left alone, and one outside
    5..69 crashes the system ("illegal wsl index").

  Status stored: none.
}

procedure mmap_$set_ws_pri;
var
  wsl_index: pinteger;
begin
  wsl_index := mmap_$ws_owner[proc1_$current];
  if (wsl_index > 69) or else (wsl_index < 5) then begin
    if wsl_index <> 0 then
      crash_system(status_$mmap_illegal_wsl_index);
  end
  else
    mmap_$wsl[wsl_index].pri_timestamp := time_$clockh;
end;
