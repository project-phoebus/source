{ tty_$i_put_chars - copy characters into a line's output buffer, with
  the output conversions.

  Image addresses:
    sau2  0x00E1AFA2  buf_put_delay (nested)
    sau2  0x00E1B00A  tty_$i_put_chars

  - While output is flushed every character counts as taken, while it
    is stopped none.  Otherwise at most the free space less avail_hint
    is taken; the result is the number taken.
  - The conversions follow output_flags (tty_$of_no_cr, _cr_to_crnl,
    _nl_to_crnl, _xtabs); 254, the delay escape, is doubled.
  - After CR, LF, TAB, VT and FF a delay sequence (buf_put_delay)
    follows when the line's delay for it is above 3.
  - A plain character is stored under the spin lock without a full
    test.
  - At the end, under the spin lock, the output-wait flag is set when
    not all were taken and the buffer holds 191 bytes or more, and the
    line's transmit callback is called.

  Status stored: none.
}

{ TODO(pascal) frame bytes unexplained (stand-ins unused_8, unused_1c)

  The SAU2 frames hold 8 bytes in the parent and 4 in the nested routine
  that no known local accounts for; the stand-ins unused_8 and unused_1c
  (and the nested routine's unused_8) take them.  Two more locals (a
  longword copy of output_flags, a word for spaces - 1) would fill 6 of
  the 8 bytes, but the image does not show that the source read the
  flags through a local (tty.ins.pas, "Types").  What the original
  declared there is not known. }

{ TODO(pascal) buf read through a stepped pointer in a `while' loop

  `ch := buf[chars_processed + 1]' compiles, in the SAU2 image, to a
  read through buf's address as a pointer stepped from element 1, a
  strength reduction known for `for' loops only; this is a `while' loop
  (its bound, local_max, changes in the body).  A pointer local stepped
  by type transfers is the other reading.  Not settled. }

{ TODO(pascal) one member test compiles to a shift, the others to bit
  tests

  In the SAU2 image `tty_$of_cr_to_crnl in tty.output_flags' (member 0)
  is a one-bit shift into the carry, while every other member test of
  output_flags here is a bit test of the loaded longword.  It may be
  another construct, such as `odd' of the flags as an integer; not a
  known form. }

[section(wired_proc, wired_data)]
function tty_$i_put_chars(var tty: tty_$desc_t; in buf: univ tty_$chars_t;
                          count: tty_$uword_t; avail_hint: integer):
                          tty_$uword_t;
  internal;
var
  unused_8: integer32;                    { stand-in, see TODO }
  token: integer;
  ch: char;
  free_space: integer;
  chars_processed: tty_$uword_t;
  spaces: tty_$uword_t;
  local_max: integer;
  used: integer;
  i: tty_$uword_t;
  unused_1c: integer32;                   { stand-in, see TODO }
  col_mod: integer;

  { buf_put_delay - put a delay sequence into the output buffer: 254, 0
    and the delay's two bytes, high byte first.  It counts the 4 bytes
    against the parent's local_max. }
  procedure buf_put_delay(delay_val: tty_$uword_t);
  type
    delay_bytes_t = record
      case integer of
        1: (w: tty_$uword_t);             { 0x00 }
        2: (hi: char;                     { 0x00 }
            lo: char);                    { 0x01 }
    end;
  var
    unused_8: integer32;                  { stand-in, see TODO }
    delay_bytes: delay_bytes_t;
  begin
    local_max := local_max - 4;
    delay_bytes.w := delay_val;
    tty_$i_buf_put(chr(254), tty.output);
    tty_$i_buf_put(chr(0), tty.output);
    tty_$i_buf_put(delay_bytes.hi, tty.output);
    tty_$i_buf_put(delay_bytes.lo, tty.output);
  end;

begin
  { nothing goes out while output is flushed or stopped }
  if tty_$st_output_flush in tty.state_flags then begin
    tty_$i_put_chars := count;
    return;
  end;
  if tty_$st_output_stopped in tty.state_flags then begin
    tty_$i_put_chars := 0;
    return;
  end;

  { the free bytes, less those kept back }
  free_space := tty.output.head - tty.output.tail - 1;
  if free_space < 0 then
    free_space := free_space + tty_$buf_size;
  free_space := free_space - avail_hint;

  { take at most that many, none when negative }
  if count > free_space then begin
    if free_space < 0 then
      local_max := 0
    else
      local_max := free_space;
  end
  else
    local_max := count;

  chars_processed := 0;

  { one character per pass }
  while chars_processed < local_max do begin
    ch := buf[chars_processed + 1];
    chars_processed := chars_processed + 1;
    case ch of
      { BS, the column moves back }
      chr(8): begin
        tty_$i_buf_put(chr(8), tty.output);
        if tty.column <> 0 then
          tty.column := tty.column - 1;
      end;

      { CR, dropped at column 0 under member 3 (tty_$of_no_cr), LF under
        member 0 (tty_$of_cr_to_crnl) }
      chr(13): begin
        if (not (tty_$of_no_cr in tty.output_flags))
           or else (tty.column <> 0) then
          if tty_$of_cr_to_crnl in tty.output_flags then begin
            local_max := local_max - 1;
            tty_$i_buf_put(chr(10), tty.output);
            if tty.delay[tty_$delay_nl] > 3 then
              buf_put_delay(tty.delay[tty_$delay_nl]);
          end
          else begin
            tty_$i_buf_put(chr(13), tty.output);
            if tty.delay[tty_$delay_cr] > 3 then
              buf_put_delay(tty.delay[tty_$delay_cr]);
          end;
        tty.column := 0;
      end;

      { LF, a CR first under member 1 (tty_$of_nl_to_crnl) }
      chr(10): begin
        if tty_$of_nl_to_crnl in tty.output_flags then begin
          local_max := local_max - 1;
          tty_$i_buf_put(chr(13), tty.output);
          if tty.delay[tty_$delay_cr] > 3 then
            buf_put_delay(tty.delay[tty_$delay_cr]);
          tty.column := 0;
        end;
        tty_$i_buf_put(chr(10), tty.output);
        if tty.delay[tty_$delay_nl] > 3 then
          buf_put_delay(tty.delay[tty_$delay_nl]);
      end;

      { TAB, spaces to the next multiple of 8 under member 4
        (tty_$of_xtabs) }
      chr(9): begin
        col_mod := tty.column & 7;
        spaces := 8 - col_mod;
        if tty_$of_xtabs in tty.output_flags then begin
          local_max := local_max - (spaces - 1);
          for i := 1 to spaces do
            tty_$i_buf_put(' ', tty.output);
        end
        else begin
          tty_$i_buf_put(ch, tty.output);
          if tty.delay[tty_$delay_tab] > 3 then
            buf_put_delay(tty.delay[tty_$delay_tab]);
        end;
        tty.column := tty.column + spaces;
      end;

      { VT }
      chr(11): begin
        tty_$i_buf_put(ch, tty.output);
        if tty.delay[tty_$delay_vt] > 3 then
          buf_put_delay(tty.delay[tty_$delay_vt]);
      end;

      { FF }
      chr(12): begin
        tty_$i_buf_put(ch, tty.output);
        if tty.delay[tty_$delay_ff] > 3 then
          buf_put_delay(tty.delay[tty_$delay_ff]);
      end;

      { the delay escape, doubled }
      chr(254): begin
        tty_$i_buf_put(ch, tty.output);
        tty_$i_buf_put(ch, tty.output);
      end;

      { any other character, stored in place under the spin lock without
        a full test; a printing one moves the column on }
      otherwise begin
        token := ml_$spin_lock(tty_$spin_lock);
        tty.output.data[tty.output.tail] := ch;
        if tty.output.tail = tty_$buf_size then
          tty.output.tail := 1
        else
          tty.output.tail := tty.output.tail + 1;
        if ch >= ' ' then
          tty.column := tty.column + 1;
        ml_$spin_unlock(tty_$spin_lock, token);
      end;
    end;
  end;

  { under the spin lock, wait for output when the caller has more and the
    buffer is nearly full; start the transmitter }
  token := ml_$spin_lock(tty_$spin_lock);
  if chars_processed < count then begin
    used := tty.output.tail - tty.output.head;
    if used < 0 then
      used := used + tty_$buf_size;
    if used >= 191 then
      tty.state_flags := tty.state_flags + [tty_$st_output_wait];
  end;
  tty.xmit_callback^(tty.line_id);
  ml_$spin_unlock(tty_$spin_lock, token);

  tty_$i_put_chars := chars_processed;
end;
