{ PMAP_$PURGE_WS - purge or free a process's working-set list.

  Image addresses:
    sau2  0x00E146B4  PMAP_$PURGE_WS
    sau4  0x0F814F28  PMAP_$PURGE_WS
    sau9  0x3C416996  PMAP_$PURGE_WS

  - index is the process's number; flag set purges its list, clear frees
    it.

  Status stored: none.
}

procedure pmap_$purge_ws(index: integer; flag: boolean);
var
  wsl_index: pinteger;
begin
  ml_$lock(ml_$pmap_lock);
  if flag then begin
    wsl_index := mmap_$ws_owner[index];
    mmap_$purge(wsl_index);
  end
  else
    mmap_$free_wsl(index);
  ml_$unlock(ml_$pmap_lock);
end;
