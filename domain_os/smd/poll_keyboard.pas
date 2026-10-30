{ smd_$poll_keyboard - move the keyboard's pending characters into the
  event ring.

  Image addresses:
    sau2  0x00E6E84C  smd_$poll_keyboard (module-local)
    sau5  0x00E70CCA  smd_$poll_keyboard (module-local)
    sau9  0x3C475240  smd_$poll_keyboard (module-local)

  - Line 0's characters are taken while the ring has room; the result
    is whether the current unit is valid, character or not.
  - KBD_$GET_CHAR_AND_MODE writes straight into the head entry, also on
    the call that finds no character; the head then does not move.

  Status stored: none.
}

{ TODO(pascal) 4 bytes of smd_$poll_keyboard's frame not accounted

  The image's frame is 0x18 bytes; the status the call writes is below
  the module-local's 4-byte slot, where dpc puts it too.  dpc's layout of
  the declared locals (status, next_head, entry, ok and the result
  variable; `dpc --dump-locals') is 20 bytes, 4 fewer.  A `with'
  temporary in place of the pointer local takes the same 4 bytes; locals
  for the character and the mode would not be stored, since
  KBD_$GET_CHAR_AND_MODE writes the entry's bytes.  What the 4 bytes held
  is not known. }

function smd_$poll_keyboard: boolean; internal;
var
  status: status_$t;
  next_head: pinteger;
  entry: smd_event_entry_ptr_t;
  ok: boolean;
begin
  ok := false;
  if smd_$validate_unit(default_unit) then begin
    ok := true;
    repeat
      { the ring is full when the next index is the reader's }
      next_head := (event_queue_head + 1) & 16#FF;
      if next_head = event_queue_tail then exit;
      entry := addr(event_queue[event_queue_head]);
      { no more characters }
      if not kbd_$get_char_and_mode(0, entry^.char_code, entry^.modifier,
                                    status) then exit;
      { publish the character }
      entry^.unit := default_unit;
      time_$clock(entry^.timestamp);
      if entry^.modifier = chr(0) then
        entry^.event_type := smd_$evtype_int_key_meta0
      else
        entry^.event_type := smd_$evtype_int_key_normal;
      event_queue_head := next_head;
    until false;
  end;
  smd_$poll_keyboard := ok;
end;
