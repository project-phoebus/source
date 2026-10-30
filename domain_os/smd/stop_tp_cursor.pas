{ SMD_$STOP_TP_CURSOR - turn the touch-pad cursor off.

  Image addresses:
    sau2  0x00E6EACE  SMD_$STOP_TP_CURSOR
    sau5  0x00E70F4C  SMD_$STOP_TP_CURSOR
    sau9  0x3C4754BA  SMD_$STOP_TP_CURSOR

  - Under the SMD request lock the keyboard's characters go to the event
    ring and, for a valid unit, a type-11 event with no buttons.
  - With tracking on, cursor 0 is redrawn after the lock, waiting for the
    display.
  - The heading is Apollo's (customer smdu.ins.pas of SR10.2).

  Status stored: none.
}

procedure smd_$stop_tp_cursor(unit: pinteger);
begin
  tp_cursor_timeout := -1;
  ml_$lock(ml_$smd_request_lock);
  if smd_$poll_keyboard then
    smd_$enqueue_event(unit, 11, saved_cursor_pos, 0);
  ml_$unlock(ml_$smd_request_lock);
  if tracking_enabled then
    show_cursor(cursor_pos_sentinel, 0, true);
end;
