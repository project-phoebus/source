{ TPAD_$DATA - turn one locator packet into cursor motion.

  Image addresses:
    sau2  0x00E691BC  TPAD_$DATA

  - A mouse packet (device byte 16#DF) gives button bits and two signed
    byte deltas, scaled with a fractional accumulator (1/1024); an idle
    packet returns at once.
  - A bitpad packet (device byte 1) or a touchpad packet (any other)
    gives an absolute raw position; the touchpad's is refused above its
    maximum and auto-ranges over the first 1000 samples.
  - Motion below the hysteresis is dropped; in relative mode it is
    accelerated (or snapped).  The cursor is clamped to the unit's
    limits.
  - A clamp's motion that reaches the punch threshold sends an edge
    event; every packet sends the locator event.

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes no object explains (stand-in unused_18)

  The other 4 bytes have no object the code shows; the stand-in
  unused_18 holds them, declared last.  The device byte is compared
  twice from one load, and the sign-extended mouse byte is used by the
  two statements after its load (common subexpressions).  Two more
  register-held locals for the raw mouse deltas would fill the 4 bytes
  exactly (twelve words), but the x arm loads the accumulator before the
  byte, the order of one statement's two operands rather than of an
  assignment to a raw delta before it.  A lead reads the 4 bytes as a slot
  for the `with' temporary; that reading is not established outside TPAD, so
  the stand-in stays until it is. }

{ TODO(pascal) `abs' is not a known form; its value used signed and unsigned

  `abs' (ref "Abs", p. 4-12: "an integer value if number is an integer")
  is not a known form of the compiler (a move or a product and a
  negation on the sign).  Its value is compared signed with a variable,
  but unsigned with a constant and zero-extended where it becomes a
  longword: as if its type were a non-negative subrange whose compares
  and widenings the compiler picks freely.  The values differ from the signed reading only
  for abs(-32768). }

{ TODO(pascal) delta_x and delta_y computed apart and moved

  delta_x and delta_y in the tail are computed in another register and
  moved into theirs, where a register-held local's value is otherwise
  computed in its own register (two sites). }

{ TODO(pascal) the clamp reads cursor.line once but cursor.column twice

  The clamp reads tpad_$cursor.line once for its two tests but
  tpad_$cursor.column twice: the same `if ... else if' shape, not
  explained. }

{ TODO(pascal) the index: a signed longword product here, unsigned elsewhere

  The record's index: a signed word multiply indexed as a longword for
  the module's tpad_$unit, where the unit routines have an unsigned
  word multiply indexed as a word for their unitp, both integers
  compared signed.  Both forms are known, the choice not explained; a type
  of unitp other than integer (a non-negative subrange, compared signed like
  its host) would fit, but nothing else shows one. }

procedure tpad_$data(in out sample: univ tpad_$data_packet_t);
var
  edge_type: integer;
  delta_x: integer;
  delta_y: integer;
  accel_flag: boolean;
  device_changed: boolean;                { the absolute arms }
  edge_flag: boolean;                     { the clamp }
  button_bits: integer;                   { the mouse arm }
  new_button_state: integer;              { the mouse arm }
  velocity: integer;                      { relative mode }
  tfactor: integer;                       { relative mode }
  unused_18: integer32;                   { stand-in, see TODO }
begin
  { the current unit's record, for the whole body }
  with tpad_$unit_configs[tpad_$unit] do begin
    accel_flag := false;

    if sample.dev_id = 16#DF then begin
      { ---- a mouse ---- }
      tpad_$dev_type := tpad_$have_mouse;

      { the buttons, active low }
      button_bits := rshft(sample.flags & 16#70, 4);
      new_button_state := 7 - (button_bits & 1) - (button_bits & 2) * 2
                          - rshft(button_bits & 4, 1);
      if new_button_state <> tpad_$button_state then
        tpad_$re_origin_flag := true;

      { x, unless it overflowed }
      if (sample.flags & 16#03) = 0 then begin
        delta_x := (tpad_$accum_x + tpad_$signed_byte_t(sample.b0) * x_scale)
                   div 1024;
        if tpad_$re_origin_flag then
          if abs(delta_x) < hysteresis then
            delta_x := 0;
        tpad_$accum_x := tpad_$signed_byte_t(sample.b0) * x_scale
                         + tpad_$accum_x - delta_x * 1024;
        tpad_$delta_x := delta_x;
      end
      else
        delta_x := tpad_$delta_x;

      { smoothing below unit scale }
      if x_scale < 1024 then
        delta_x := (abs(delta_x) + 10) * delta_x div 10;

      { y, unless it overflowed }
      if rshft(sample.flags & 16#0C, 2) = 0 then begin
        delta_y := (tpad_$accum_y - tpad_$signed_byte_t(sample.b1) * y_scale)
                   div 1024;
        if tpad_$re_origin_flag then
          if abs(delta_y) < hysteresis then
            delta_y := 0;
        tpad_$accum_y := -tpad_$signed_byte_t(sample.b1) * y_scale
                         + tpad_$accum_y - delta_y * 1024;
        tpad_$delta_y := delta_y;
      end
      else
        delta_y := tpad_$delta_y;

      if y_scale < 1024 then
        delta_y := (abs(delta_y) + 10) * delta_y div 10;

      { an idle packet ends here }
      if new_button_state = tpad_$button_state then
        tpad_$re_origin_flag := accel_flag;
      if (new_button_state = tpad_$button_state) and then (delta_x = 0)
         and then (delta_y = 0) then
        return;

      tpad_$button_state := new_button_state;
      tpad_$cursor.column := tpad_$cursor.column + delta_x;
      tpad_$cursor.line := tpad_$cursor.line + delta_y;
    end
    else begin
      if sample.dev_id = 1 then begin
        { ---- a bitpad ---- }
        device_changed := tpad_$dev_type <> tpad_$have_bitpad;
        tpad_$dev_type := tpad_$have_bitpad;

        { six bits a byte }
        tpad_$raw_x := lshft(sample.b1, 6) + sample.b0;
        tpad_$raw_y := lshft(sample.b3, 6) + sample.b2;

        { scaled, y inverted }
        tpad_$raw_x := tpad_$raw_x * x_scale div 2200;
        tpad_$raw_y := y_scale - tpad_$raw_y * y_scale div 2200;

        tpad_$button_state := rshft(sample.flags & 16#3C, 2);
      end
      else begin
        { ---- a touchpad ---- }
        device_changed := tpad_$dev_type <> tpad_$have_touchpad;
        tpad_$dev_type := tpad_$have_touchpad;
        tpad_$button_state := 0;

        { twelve bits for each axis }
        tpad_$raw_x := sample.flags + lshft(sample.b0 & 16#0F, 8);
        tpad_$raw_y := rshft(sample.b0 & 16#F0, 4) + lshft(sample.b1, 4);

        { the inverted orientation }
        if tpad_$touchpad_max >= 16#1000 then begin
          tpad_$raw_x := 16#0FFF - tpad_$raw_x;
          tpad_$raw_y := 16#0FFF - tpad_$raw_y;
        end;

        { off the pad }
        if (tpad_$touchpad_max < tpad_$raw_x)
           or else (tpad_$touchpad_max < tpad_$raw_y) then
          return;

        { auto-ranging over the first samples }
        sample_count := sample_count + 1;
        if sample_count < 1000 then begin
          if tpad_$raw_x + 50 < x_min then
            x_min := tpad_$raw_x + 50;
          if tpad_$raw_x - 50 - x_min > x_range then begin
            x_range := tpad_$raw_x - 50 - x_min;
            if x_scale = 0 then
              x_factor := 1024
            else
              x_factor := x_range div x_scale;
          end;
          if tpad_$raw_y + 50 < y_min then
            y_min := tpad_$raw_y + 50;
          if tpad_$raw_y - 50 - y_min > y_range then begin
            y_range := tpad_$raw_y - 50 - y_min;
            if y_scale = 0 then
              y_factor := 1024
            else
              y_factor := y_range div y_scale;
          end;
        end;

        { after a long gap, absolutely }
        if (sample.elapsed > 125000) and then (mode = tpad_$rel_abs) then begin
          tpad_$cursor.column := x_max_disp + 1
                                 - (tpad_$raw_x - x_min) * x_max_disp div x_range;
          tpad_$cursor.line := (tpad_$raw_y - y_min) * (y_max_disp + 1)
                               div y_range;
        end;

        { into the unit's range }
        tpad_$raw_x := x_scale - (tpad_$raw_x - x_min) * x_scale div x_range;
        tpad_$raw_y := (tpad_$raw_y - y_min) * y_scale div y_range;
      end;

      { ---- the absolute devices' motion ---- }
      if ((sample.elapsed > 31250) or device_changed)
         and then (mode <> tpad_$absolute) then begin
        cursor_offset.column := tpad_$cursor.column - tpad_$raw_x;
        cursor_offset.line := tpad_$cursor.line - tpad_$raw_y;
      end;

      delta_x := tpad_$raw_x + cursor_offset.column - tpad_$cursor.column;
      delta_y := tpad_$raw_y + cursor_offset.line - tpad_$cursor.line;

      { relative mode's acceleration }
      if mode = tpad_$relative then begin
        velocity := abs(delta_x * x_factor) + abs(delta_y * y_factor);
        if velocity > 100 then begin
          tfactor := (sample.clock.low32 - tpad_$last_clock.low32) div 9000;
          if tfactor > 1 then
            velocity := velocity div tfactor;
          velocity := velocity div 100 + 1;
          delta_x := delta_x * velocity;
          delta_y := delta_y * velocity;
          accel_flag := true;
        end
        else if delta_y <> 0 then
          if abs(delta_x div delta_y) > 5 then begin
            delta_y := 0;
            accel_flag := true;                     { shared }
          end;
        tpad_$last_clock := sample.clock;
      end;

      { motion beyond the hysteresis, x }
      if delta_x > hysteresis then
        tpad_$cursor.column := delta_x + tpad_$cursor.column - hysteresis
      else if -hysteresis > delta_x then
        tpad_$cursor.column := delta_x + tpad_$cursor.column + hysteresis;

      { y }
      if delta_y > hysteresis then
        tpad_$cursor.line := tpad_$cursor.line + delta_y - hysteresis
      else if -hysteresis > delta_y then
        tpad_$cursor.line := tpad_$cursor.line + delta_y + hysteresis;
    end;

    { ---- the cursor clamped to the unit ---- }
    edge_flag := false;
    if tpad_$cursor.line < y_min_disp then begin
      edge_type := 0;
      tpad_$cursor.line := y_min_disp;
      edge_flag := true;
    end
    else if tpad_$cursor.line > y_max_disp then begin
      edge_type := 1;
      tpad_$cursor.line := y_max_disp;
      edge_flag := true;
    end;
    if tpad_$cursor.column < x_min_disp then begin
      edge_type := 2;
      tpad_$cursor.column := x_min_disp;
      edge_flag := true;
    end
    else if tpad_$cursor.column > x_max_disp then begin
      edge_type := 3;
      tpad_$cursor.column := x_max_disp;
      edge_flag := true;
    end;

    { re-origin after an acceleration or a clamp }
    if (accel_flag or edge_flag) and then (mode <> tpad_$absolute) then begin
      cursor_offset.column := tpad_$cursor.column - tpad_$raw_x;
      cursor_offset.line := tpad_$cursor.line - tpad_$raw_y;
    end;

    sample.elapsed := 0;

    { the edge event }
    if edge_flag then
      if abs(delta_x) + abs(delta_y) >= punch_impact then
        smd_$loc_event(true, tpad_$unit, tpad_$cursor, edge_type);

    { the locator event }
    smd_$loc_event(false, tpad_$unit, tpad_$cursor, tpad_$button_state);
  end;
end;
