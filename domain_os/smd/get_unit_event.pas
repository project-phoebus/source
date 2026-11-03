{ SMD_$GET_UNIT_EVENT - take the next event off the display's event ring.

  Image addresses:
    sau2  0x00E6EEA8  SMD_$GET_UNIT_EVENT
    sau4  0x0F8795EC  SMD_$GET_UNIT_EVENT
    sau5  0x00E71258  SMD_$GET_UNIT_EVENT
    sau9  0x3C4756AA  SMD_$GET_UNIT_EVENT

  - Under the SMD request lock the keyboard's characters go to the ring
    first; an event taken unblanks the screen.
  - blank_enabled is set at the end, either way.
  - Ring types 1..6, 9, 10 and 16 up leave the event type unassigned.

  Status stored:
    status_$ok: always (event_type smd_$evtype_none when the ring is
      empty)
}

procedure smd_$get_unit_event(out event_type: integer;
                              out event_data: smd_unit_event_t;
                              out status: status_$t);
var
  ue: smd_unit_event_t;
  entry: smd_event_entry_ptr_t;
  result_type: integer;
begin
  status.all := status_$ok;
  event_type := smd_$evtype_none;
  ml_$lock(ml_$smd_request_lock);
  discard(smd_$poll_keyboard);
  entry := addr(event_queue[event_queue_tail]);
  if event_queue_head <> event_queue_tail then begin
    ue.hdr.pos := entry^.pos;
    ue.hdr.timestamp := entry^.timestamp;
    ue.unit := entry^.unit;
    case entry^.event_type of
      smd_$evtype_int_button_down,
      smd_$evtype_int_button_down2: begin
        result_type := smd_$evtype_button_down;
        ue.button_or_char := entry^.button_or_char;
      end;
      smd_$evtype_int_button_up: begin
        result_type := smd_$evtype_button_up;
        ue.button_or_char := entry^.button_or_char;
      end;
      smd_$evtype_int_special: begin
        result_type := smd_$evtype_special;
      end;
      smd_$evtype_int_key_meta0,
      smd_$evtype_int_key_meta: begin
        result_type := smd_$evtype_keystroke;
        ue.char_code := entry^.char_code;
        ue.modifier := chr(0);
      end;
      smd_$evtype_int_key_normal: begin
        result_type := smd_$evtype_keystroke;
        ue.char_code := entry^.char_code;
        ue.modifier := entry^.modifier;
      end;
      smd_$evtype_int_pointer_up: begin
        result_type := smd_$evtype_pointer_up;
        ue.button_or_char := entry^.button_or_char;
      end;
    end;
    event_queue_tail := (event_queue_tail + 1) & 16#FF;
    ml_$unlock(ml_$smd_request_lock);
    smd_$unblank;
    event_data := ue;
    event_type := result_type;
  end
  else
    ml_$unlock(ml_$smd_request_lock);
  blank_flags.blank_enabled := true;
end;
