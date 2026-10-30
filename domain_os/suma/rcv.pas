{ SUMA_$RCV - a bitpad line's receive handler: one byte of a packet.

  Image addresses:
    sau2  0x00E1AD18  SUMA_$RCV

  - The bitpad sends packets of five bytes: byte 0, the sync byte, has
    bit 6 set and the identification bits; bytes 1 to 4 give six bits
    each of the coordinates.
  - A complete sample that moved (its low parts by more than the
    threshold's high byte, or its high parts or identification changed)
    is queued in TERM_$TPAD_BUFFER with a deferred TERM_$ENQUEUE_TPAD.
  - The threshold is reset when a sample is queued, else (also when the
    buffer is full) grows, up to its maximum.
  - DXM_$ADD_CALLBACK's status is ignored.

  Status stored: none.
}

{ TODO(pascal) the sync test is a bit test on the held byte

  Arm 0 tests bit 6 of data_byte with a bit test.  The known form of
  `&' with a constant loads the constant first, and a bit test on a
  register is known only as the member test of a set held in it (and
  `odd'); a set parameter would not allow the `&' the other arms apply
  to the same byte.  Taken: `(data_byte & 16#40) <> 0'. }

{ TODO(pascal) the threshold's high byte is read as a byte

  The coordinates' differences are compared with the high byte of
  suma_$threshold, a byte load zero-extended to a longword, compared in
  32 bits unsigned.  Read here as `rshft(suma_$threshold, 8)' (ref
  p. 4-171: rshft widens its operand to 32 bits first); `div 256' fits
  too.  Neither gives the byte load in a known form of the compiler; a
  variant record over the word would, but nothing in the image shows
  one. }

{ TODO(pascal) the packed fields' constant stores use the record's word

  suma_$cur.id_bits.bits_7_6 := 0 and .bits_1_0 := 0 are done on the
  packed record's word at +0x0A, where the known form takes the byte the
  field lies in; the merge of .id and the reads use the byte.  KBD_$RCV
  shows the same split.  Whether the identification byte was a packed
  record in the source is the reading of suma/suma.ins.pas. }

procedure suma_$rcv(param_1: univ_ptr; data_byte: suma_$byte_t);
  options(val_param);
var
  status: status_$t;
  current_time: time_$clock_t;
  is_duplicate: boolean;
  next_head: pinteger;

  { TODO(pascal) 4 frame bytes hold no object the code addresses

    The stand-in unused_14 holds their place.  A lead: arm 4 reaches
    term_$tpad_buffer through one held address, which a `with
    term_$tpad_buffer do' would give, with 4 bytes for its temporary as
    in TPAD's routines; plain references give the same code.  Not
    settled. }
  unused_14: integer32;

begin
  case suma_$rcv_state of

    { the sync byte }
    0: begin
      if (data_byte & 16#40) <> 0 then begin
        suma_$prev := suma_$cur;
        suma_$cur.id_bits.bits_7_6 := 0;
        suma_$cur.id_bits.bits_1_0 := 0;
        suma_$cur.id_bits.id := rshft(data_byte, 2) & 16#F;
        suma_$rcv_state := suma_$rcv_state + 1;     { merged with arm 3's }
      end;
    end;

    { the coordinates' first three bytes }
    1: begin
      suma_$cur.x_high := data_byte & 16#3F;
      suma_$rcv_state := suma_$rcv_state + 1;       { merged with arm 3's }
    end;
    2: begin
      suma_$cur.x_low := data_byte & 16#3F;
      suma_$rcv_state := suma_$rcv_state + 1;       { merged with arm 3's }
    end;
    3: begin
      suma_$cur.y_high := data_byte & 16#3F;
      suma_$rcv_state := suma_$rcv_state + 1;
    end;

    { the last byte, and the complete sample }
    4: begin
      suma_$cur.y_low := data_byte & 16#3F;
      suma_$rcv_state := 0;

      { a new sample, or the same as the last }
      is_duplicate := false;
      if (suma_$prev.id_bits.id <> suma_$cur.id_bits.id)
         or else (abs(suma_$prev.x_high - suma_$cur.x_high) >
                  rshft(suma_$threshold, 8))
         or else (suma_$prev.x_low <> suma_$cur.x_low)
         or else (abs(suma_$prev.y_high - suma_$cur.y_high) >
                  rshft(suma_$threshold, 8))
         or else (suma_$prev.y_low <> suma_$cur.y_low) then
        is_duplicate := true;

      { the buffer's next producer position }
      next_head := term_$tpad_buffer.head + 1;
      if next_head = suma_$tpad_buffer_size then
        next_head := 0;

      time_$clock(current_time);

      if is_duplicate and then (next_head <> term_$tpad_buffer.tail)
      then begin
        suma_$cur.timestamp := current_time;
        suma_$cur.delta_time :=
          suma_$cur.timestamp.low32 - suma_$last_time;
        term_$tpad_buffer.samples[term_$tpad_buffer.head] :=
          suma_$cur;
        term_$tpad_buffer.head := next_head;
        dxm_$add_callback(dxm_$unwired_q, addr(term_$enqueue_tpad),
                          addr(suma_$tpad_buffer), 4, true, status);
        suma_$threshold := suma_initial_threshold;
      end
      else begin
        suma_$threshold := suma_$threshold + suma_threshold_increment;
        if suma_$threshold > suma_max_threshold then
          suma_$threshold := suma_max_threshold;
      end;

      suma_$last_time := current_time.low32;
    end;
  end;
end;
