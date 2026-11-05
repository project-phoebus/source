{ SMD_$LOC_EVENT - take a locator event into the event ring.

  Image addresses:
    sau2  0x00E6E9A0  SMD_$LOC_EVENT
    sau4  0x0F879132  SMD_$LOC_EVENT
    sau5  0x00E70E1E  SMD_$LOC_EVENT
    sau6  0x78078188  SMD_$LOC_EVENT
    sau7  0x3C481C6A  SMD_$LOC_EVENT
    sau9  0x3C47538A  SMD_$LOC_EVENT

  - Under the SMD request lock; the keyboard's characters go to the ring
    first.
  - A new position is merged into the ring's last entry when it can be
    (reporting on, the same unit and event type, or an edge over a
    pending type 13), else appended as type 15 (an edge) or 13.
  - A non-edge event with changed buttons appends a type 14; with
    tracking on, the cursor follows the position after the lock.

  Status stored: none.
}

procedure smd_$loc_event(event_type: boolean; unit: integer;
                         pos: smd_$pos_t; buttons: integer);
  options(val_param);
var
  changed: boolean;
  entry_type: integer;
  prev: integer;
  coalesced: boolean;
  entry: smd_event_entry_ptr_t;
begin
  ml_$lock(ml_$smd_request_lock);
  if smd_$poll_keyboard then begin
    changed := saved_cursor_pos <> pos;
    if changed then begin
      if event_type then
        entry_type := 15
      else
        entry_type := 13;
      prev := (event_queue_head + 255) mod 256;
      coalesced := false;
      entry := addr(event_queue[prev]);
      { merge the move into the ring's last entry }
      if (event_queue_head <> event_queue_tail) and then
         (tp_reporting <> 0) and then
         (unit = entry^.unit) then
        if entry_type = entry^.event_type then begin
          entry^.button_or_char := buttons;
          entry^.pos := pos;
          coalesced := true;
        end
        else if event_type and then
                (entry^.event_type = smd_$evtype_int_button_down2)
        then begin
          entry^.event_type := smd_$evtype_int_pointer_up;
          entry^.button_or_char := buttons;
          entry^.pos := pos;
          coalesced := true;
        end;
      if not coalesced then
        smd_$enqueue_event(unit, entry_type, pos, buttons);
      tp_cursor_timeout := 0;
      saved_cursor_pos := pos;
    end;
    { a button change of a non-edge event }
    if not event_type and then
       (buttons <> last_button_state) then begin
      smd_$enqueue_event(unit, 14, pos, buttons);
      last_button_state := buttons;
    end;
  end
  else
    changed := false;
  ml_$unlock(ml_$smd_request_lock);
  if changed and tracking_enabled then
    show_cursor(pos, tracking_cursor_num, false);
end;
