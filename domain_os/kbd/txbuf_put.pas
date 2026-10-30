{ kbd_$txbuf_put - copy characters into the console's transmit buffer and
  start the line.

  Image addresses:
    sau9  0x3C41F5C0  kbd_$txbuf_put (module-local)

  - Copies as many of the count characters as the buffer has room for,
    from the string's first, and returns how many; a count of 0 returns
    0 at once.
  - The buffer keeps one position free: the room is head - tail - 1,
    modulo the size.
  - The line's transmit start is called after every copy, whatever
    was copied.

  Status stored: none.
}

{ TODO(pascal) 8 unaddressed frame bytes (stand-ins unused_8, unused_c)

  The frame has 8 bytes more than the locals the code shows (the slot
  of a module-local routine, room, n, i and the result), and no
  instruction reaches them.  No other SAU's copy has them in use: the
  SAU6, SAU7 and SAU8 copies are the same code.  The copy loop steps a
  pointer through the string, which a pointer local of the source would
  explain for 4 of them; that is not known.  The stand-ins hold the
  place. }

function kbd_$txbuf_put(var kbd: kbd_$desc_t; in str: univ kbd_$chars_t;
                        count: pinteger): integer; internal;
var
  unused_8: integer32;                    { the stand-ins (TODO) }
  unused_c: integer32;
  room: integer;
  n: integer;
  i: pinteger;
begin
  if count = 0 then begin
    kbd_$txbuf_put := 0;
    return;
  end;

  { the room left, one position kept free }
  room := kbd.txbuf.head - kbd.txbuf.tail - 1;
  if room < 0 then
    room := room + kbd_$ring_size;

  if count > room then begin
    if room < 0 then
      n := 0
    else
      n := room;
  end
  else
    n := count;

  { copy, the producer position wrapping from the last to 1 }
  i := 0;
  while i < n do begin
    kbd.txbuf.data[kbd.txbuf.tail] := str[i + 1];
    if kbd.txbuf.tail = kbd_$ring_size then
      kbd.txbuf.tail := 1
    else
      kbd.txbuf.tail := kbd.txbuf.tail + 1;
    i := i + 1;
  end;

  kbd_$tstart_t(kbd.handlers[1])^(kbd.field_10);
  kbd_$txbuf_put := n;
end;
