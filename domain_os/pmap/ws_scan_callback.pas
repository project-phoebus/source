{ PMAP_$WS_SCAN_CALLBACK - a working-set scan timer's callback.

  Image addresses:
    sau2  0x00E144F6  PMAP_$WS_SCAN_CALLBACK
    sau9  0x3C4167DC  PMAP_$WS_SCAN_CALLBACK

  - arg's word at +2 is the process's number (the TODO(pascal) below); a
    number above 64 crashes the system.
  - Each call counts a tick on the process's list, and every 8 clock
    ticks one on the wired list (5); a list is scanned whole at
    PMAP_$WS_INTERVAL ticks.

  Status stored: none.
}

{ TODO(pascal) what PMAP_$WS_SCAN_CALLBACK's argument points to

  The body reads the word at +2 of what its argument's pointer points
  to.  TIME_$Q_SCAN_QUEUE calls an element's callback with the element's
  pointer by address (time/q_scan_queue.pas), which would make that word
  the low half of the element's next link; PMAP_$INIT_WS_SCAN stores the
  process's number as the element's callback_arg (+8), not at +2.
  Either the virtual-timer queue calls its callbacks differently
  (TIME_$VT_INT, not checked here) or the original reads a field this
  file does not explain.  The heading reads the argument as a record
  whose word at +2 is the process's number. }

procedure pmap_$ws_scan_callback(in arg: pmap_$ws_scan_arg_ptr_t);
var
  pid: pinteger;
  slot: pinteger;
  now: integer32;
begin
  pid := arg^.pid;
  if pid > 64 then
    crash_system(status_$pmap_illegal_pid_argument);
  ml_$lock(ml_$pmap_lock);

  { the process's own list }
  slot := mmap_$ws_owner[pid];
  if slot <> 0 then
    with mmap_$wsl[slot] do begin
      owner := owner + 1;
      if owner >= pmap_$ws_interval then begin
        owner := 0;
        scan_pos := page_count;
        ws_timestamp := time_$clockh;
        discard(mmap_$ws_scan(slot, false, 16#3FFFFF, 16#3FFFFF));
      end;
    end;

  { the wired list, every 8 ticks }
  now := time_$clockh;
  if mmap_$wsl[5].ws_timestamp + 8 < now then begin
    mmap_$wsl[5].pri_timestamp := now;
    mmap_$wsl[5].ws_timestamp := now;
    mmap_$wsl[5].owner := mmap_$wsl[5].owner + 1;
    if mmap_$wsl[5].owner >= pmap_$ws_interval then begin
      mmap_$wsl[5].owner := 0;
      mmap_$wsl[5].scan_pos := mmap_$wsl[5].page_count;
      discard(mmap_$ws_scan(5, false, 16#3FFFFF, 16#3FFFFF));
    end;
  end;

  ml_$unlock(ml_$pmap_lock);
end;
