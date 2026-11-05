{ smd_$enqueue_event - append an event to the event ring.

  Image addresses:
    sau2  0x00E6E8D6  smd_$enqueue_event (module-local)
    sau4  0x0F879068  smd_$enqueue_event (module-local)
    sau5  0x00E70D54  smd_$enqueue_event (module-local)
    sau6  0x780780C8  smd_$enqueue_event (module-local)
    sau7  0x3C481BAA  smd_$enqueue_event (module-local)
    sau9  0x3C4752CA  smd_$enqueue_event (module-local)

  - The event is dropped when the ring is full; else DTTE line 0's
    first eventcount is advanced.

  Status stored: none.
}

procedure smd_$enqueue_event(unit: integer; event_type: integer;
                             pos: smd_$pos_t; buttons: integer);
  internal;
var
  next_head: pinteger;
begin
  { the ring is full when the next index is the reader's;
    the event is dropped }
  next_head := (event_queue_head + 1) & 16#FF;
  if next_head <> event_queue_tail then begin
    time_$clock(event_queue[event_queue_head].timestamp);
    event_queue[event_queue_head].pos := pos;
    event_queue[event_queue_head].event_type := event_type;
    event_queue[event_queue_head].button_or_char := buttons;
    event_queue[event_queue_head].unit := unit;
    event_queue_head := next_head;
    ec_$advance(ec_$eventcount_ptr_t(addr(dtte[0].ec_00))^);
  end;
end;
