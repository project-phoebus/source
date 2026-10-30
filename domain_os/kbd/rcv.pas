{ KBD_$RCV - the console line's receive handler: one byte from the
  keyboard.

  Image addresses:
    sau2  0x00E1CCC0  KBD_$RCV
    sau2  0x00E1CC10  kbd_$process_key (nested)
    sau2  0x00E1CC64  kbd_$translate_key (nested)
    sau9  0x3C41F942  KBD_$RCV
    sau9  0x3C41F892  kbd_$process_key (nested)
    sau9  0x3C41F8E6  kbd_$translate_key (nested)

  - The byte runs through the keyboard state machine; keys go to the key
    ring (kbd_$process_key).
  - The manual stop key crashes the system unless the MMU is in normal
    mode.
  - A touchpad report's fourth byte, with no handler installed, queues
    the sample in TERM_$TPAD_BUFFER and TERM_$ENQUEUE_TPAD as a deferred
    call; with a handler, the ring is drained into it.
  - With `kbd_commands' the keyboard's answers to the mode and type
    commands (actions 7, 8, 9, 13, 14) set the keyboard type and its
    string, and queue a 16#FF before the byte.
  - kbd_$translate_key reaches no enclosing frame, but lies in KBD_$RCV's
    family, its only caller: so nested.

  Status stored: none.
}

{ TODO(pascal) the `while' condition's value is stored in a temporary

  `while kbd_$fetch_key(...) do' compiled as the other loops are would
  test D0 after the call; the image stores the byte in the frame, loads
  fetched_mode for the body's first test, and tests the stored byte.  A
  boolean local assigned from the call (`got := kbd_$fetch_key(...)'
  before the loop and again at the end of the body, `while got do')
  gives the slot, but the frame then needs it among the locals, above
  the DXM temporary, and the image has it below; and the call before the
  loop would have to be merged with the one in the body.  Taken: the
  condition, its value stored in a temporary, which is where the frame
  puts it.  Not a known form. }

{ TODO(pascal) next_state := 15 is an or on the record's word

  `entry^.next_state := 15' sets the field's every bit with an or
  ("the `ori' alone when every bit is set"), but on the record's word
  rather than on the byte the field lies in, and through a register (as
  at six sites that put a constant into memory through a register).  The
  packed field's unit as the image uses it differs from the one the
  reads use (the byte); not a known form. }

{ TODO(pascal) KBD_$RCV saves no data register: ch is read from its slot

  KBD_$RCV saves no data register: ch is read from its slot at each
  use, where TTY_$I_RCV loads its character into a register at entry,
  and the only register-held local, next, lives in D0 with no call in
  its range.  Whether a routine with nested routines loads its by-value
  parameters at entry is not settled (PMAP_$FLUSH, a parent, loads one
  of its parameters at entry and re-reads the ones its nested routines
  read; no nested routine reads ch here). }

procedure kbd_$rcv(var kbd: kbd_$desc_t; ch: char); options(val_param);
var
  entry: kbd_$state_entry_ptr_t;
  dxm_status: status_$t;
  now: time_$clock_t;
  next: integer;
  fetched_mode: integer;
  new_head: pinteger;                     { the nested routine's too }
  fetched_key: char;
%if kbd_commands %then
  old_type: integer;
%endif

  { kbd_$process_key - queue a key in the line's ring.

    The key is stored at the ring's producer position, which then
    advances (64 wraps to 1), and the line's key eventcount is advanced;
    when the ring is full the key is dropped.  The next position is kept
    in KBD_$RCV's new_head, which the routine reaches through its link:
    it is not passed.  Caller: KBD_$RCV, with ch by value in the high
    byte of a word and kbd by address (a nested routine takes
    `internal''s by-value convention).  kbd.ring.tail is read from
    memory once for each reference; the shape of tty_$i_buf_put
    (tty/i_buf_put.pas).
  }

  procedure kbd_$process_key(ch: char; var kbd: kbd_$desc_t);
  begin
    { the next producer position, the last wraps to 1 }
    if kbd.ring.tail = kbd_$key_ring_size then
      new_head := 1
    else
      new_head := kbd.ring.tail + 1;

    { full when the next position is the consumer's; the key is
      dropped }
    if new_head <> kbd.ring.head then begin
      kbd.ring.data[kbd.ring.tail] := ch;
      kbd.ring.tail := new_head;
      ec_$advance_without_dispatch(kbd.key_ec^);
    end;
  end;

  { kbd_$translate_key - map a few key codes to control characters.

    F1 becomes ^V, R2 ^X, R3 ^D, BS backspace, CR carriage return, and
    the three tab keys (CTAB, STAB, TAB) horizontal tab; any other code
    comes back unchanged.  Nested in KBD_$RCV (it lies in KBD_$RCV's
    family, above; it reaches no enclosing frame, so it is passed no
    link).  Caller: KBD_$RCV, the code a byte by value after the pad, the
    result a byte.  The `case' is a compare chain (8 labels over 0x30
    values), the three tab labels tested in the order CTAB, STAB, TAB,
    the `otherwise' part reached by the chain's branch.
  }

  function kbd_$translate_key(ch: char): char;
  begin
    case ch of
      kbd_$f1: kbd_$translate_key := chr(16#16);
      kbd_$r2: kbd_$translate_key := chr(16#18);
      kbd_$r3: kbd_$translate_key := chr(4);
      kbd_$bs: kbd_$translate_key := chr(8);
      kbd_$cr: kbd_$translate_key := chr(13);
      kbd_$ctab, kbd_$stab, kbd_$tab: kbd_$translate_key := chr(9);
      otherwise
        kbd_$translate_key := ch;
    end;
  end;

begin
  entry := kbd_$state_lookup(kbd.state, ch);

  case entry^.action of
    0: { empty };

    { the manual stop key }
    2: begin
      if not mmu_$normal_mode then begin
        crash_system(16#000B0008);  { manual stop: type G<ret>G *+2<ret>
                                      to continue }
        kbd_$crash_init;
        entry^.next_state := 15;
      end
      else
        kbd_$process_key(ch, kbd);                  { merged with the next arm }
    end;

    { a key }
    1, 10, 11, 12: begin
      kbd_$process_key(ch, kbd);
    end;

    { the four bytes of a touchpad report }
    3: begin
      kbd.sample.id_flags := ch;
      kbd.tpad_ptr := addr(kbd.sample.reserved_0b);
    end;
    4: begin
      kbd.tpad_ptr^[0] := ch;
    end;
    5: begin
      kbd.tpad_ptr^[1] := ch;
    end;
    6: begin
      kbd.tpad_ptr^[2] := ch;
      if kbd.handler = nil then begin
        new_head := term_$tpad_buffer.head + 1;
        if new_head = suma_$tpad_buffer_size then
          new_head := 0;
        time_$clock(now);
        if term_$tpad_buffer.tail <> new_head then begin
          kbd.sample.timestamp := now;
          kbd.sample.delta_time :=
            kbd.sample.timestamp.low32 - kbd.last_time;
          term_$tpad_buffer.samples[term_$tpad_buffer.head] :=
            kbd.sample;
          term_$tpad_buffer.head := new_head;
          dxm_$add_callback(dxm_$unwired_q, addr(term_$enqueue_tpad),
                            addr(kbd.tpad_buffer), 4, true, dxm_status);
        end;
        kbd.last_time := now.low32;
      end;
    end;
%if kbd_commands %then

    { the keyboard's answer to a mode command: the keyboard type; a
      return to type 0 from type 0 or 1 clears the command's flag; the
      byte is queued after a 16#FF but on a change from type 2 to 1 }
    7: begin
      old_type := kbd.kbd_type_idx;
      kbd.kbd_type_idx := kbd_$get_mode(ch);
      if (kbd.kbd_type_idx = 0) and then (old_type in [0, 1]) then
        kbd.flags := kbd.flags - [kbd_$flag_cmd_sent];
      if (kbd.kbd_type_idx <> 1) or else (old_type <> 2) then begin
        kbd_$process_key(chr(16#FF), kbd);
        kbd_$process_key(ch, kbd);
      end;
    end;
    { the type, then a touchpad report started as by the keys 16#DF and
      16#E8 (action 3) }
    8: begin
      kbd.kbd_type_idx := kbd_$get_mode(ch);
      kbd.sample.id_flags := chr(16#DF);
      kbd.tpad_ptr := addr(kbd.sample.reserved_0b);
    end;
    9: begin
      kbd.kbd_type_idx := kbd_$get_mode(ch);
      kbd.sample.id_flags := chr(16#E8);
      kbd.tpad_ptr := addr(kbd.sample.reserved_0b);
    end;
    { the keyboard type string's two characters }
    13: begin
      kbd.kbd_type_str[0] := ch;
      kbd_$process_key(chr(16#FF), kbd);
      kbd_$process_key(ch, kbd);
    end;
    14: begin
      kbd.kbd_type_str[1] := ch;
      kbd_$set_type(kbd, kbd.kbd_type_str, 2);
      kbd_$process_key(ch, kbd);
    end;
%endif
  end;

  { the next state }
  next := entry^.next_state;
  if next = 15 then
    kbd.state := kbd_$escape_state[kbd.kbd_type_idx]
  else
    kbd.state := next;

  { drain the ring into the handler }
  if kbd.handler <> nil then
    while kbd_$fetch_key(kbd, fetched_key, fetched_mode) do
      if fetched_mode = 0 then
        kbd.handler^(kbd.user_data, kbd_$translate_key(fetched_key));
end;
