{ PMAP_$INIT_WS_SCAN - set a process's working-set list and start its timer.

  Image addresses:
    sau2  0x00E145F0  PMAP_$INIT_WS_SCAN
    sau4  0x0F814E64  PMAP_$INIT_WS_SCAN
    sau6  0x78014DB8  PMAP_$INIT_WS_SCAN
    sau7  0x3C41630E  PMAP_$INIT_WS_SCAN
    sau9  0x3C4168D2  PMAP_$INIT_WS_SCAN

  - index is the process's number, ws_param its working-set list.
  - List 5, the wired list, gets no scan timer.
  - The timer queue's statuses are ignored.

  Status stored: none.
}

procedure pmap_$init_ws_scan(index: pinteger; ws_param: integer);
var
  wsl: pinteger;
  status: status_$t;
  when: time_$clock_t;
begin
  wsl := ws_param;
  mmap_$set_ws_index(index, wsl);
  if ws_param = 5 then
    return;

  time_$q_remove_elem(time_$vtq[index], pmap_$ws_timer[index].elem, status);
  with pmap_$ws_timer[index].elem do begin
    flags := [1, 3, 4];
    expire.high16 := 0;
    expire.low32 := 250000;
    interval := expire;
    callback := addr(pmap_$ws_scan_callback);
    callback_arg := univ_ptr(linteger(index));
    when.high := 0;
    when.low := 0;
    time_$q_enter_elem(time_$vtq[index], when, pmap_$ws_timer[index].elem,
                       status);
  end;
end;
