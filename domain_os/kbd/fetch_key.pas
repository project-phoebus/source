{ kbd_$fetch_key - take the next key from a keyboard line's ring.

  Image addresses:
    sau2  0x00E1CAFE  kbd_$fetch_key (module-local)
    sau6  0x7801EB4C  kbd_$fetch_key (module-local)
    sau7  0x3C420E38  kbd_$fetch_key (module-local)

  - The ring's bytes run through the keyboard state machine from the
    descriptor's sub_state until one yields a key or the ring is empty;
    the result is true when key_out holds a key.
  - Mode 0 translates through the line's table; action 12 translates
    bytes above 16#7F through SMD_$KTT and makes mode_out 7.
  - Next state 15 is the escape state of the current mode.

  Status stored: none.
}

function kbd_$fetch_key(var kbd: kbd_$desc_t; out key_out: char;
                        out mode_out: integer): boolean; internal;
var
  entry: kbd_$state_entry_ptr_t;
  head: pinteger;
  sub_state: integer;
  next: integer;
  found: boolean;
  high_key: boolean;
begin
  found := false;
  mode_out := kbd.pending_mode;
  sub_state := kbd.sub_state;
  head := kbd.ring.head;
  high_key := false;

  { until a byte yields a key or the ring is empty }
  while (not found) and then (head <> kbd.ring.tail) do begin
    key_out := kbd.ring.data[head];
    if head = kbd_$key_ring_size then
      head := 1
    else
      head := head + 1;

    entry := kbd_$state_lookup(sub_state, key_out);

    case entry^.action of
      0: { empty };
      1, 2, 13, 14: begin
        if mode_out = 0 then
          key_out := kbd.ktt_ptr^[key_out];
        found := true;
      end;
      10: begin
        key_out := chr(16#CB);
        found := true;
      end;
      12: begin
        if key_out > chr(16#7F) then
          key_out := smd_$ktt[key_out];
        high_key := true;
        found := true;
      end;
      7: begin
        mode_out := kbd_$get_mode(key_out);
      end;
    end;

    { the next state }
    next := entry^.next_state;
    if next = 15 then
      sub_state := kbd_$escape_state[mode_out]
    else
      sub_state := next;
  end;

  kbd.ring.head := head;
  kbd.sub_state := sub_state;
  kbd.pending_mode := mode_out;
  if high_key then
    mode_out := 7;
  kbd_$fetch_key := found;
end;
