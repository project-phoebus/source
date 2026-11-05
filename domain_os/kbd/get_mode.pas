{ kbd_$get_mode - the mode a mode key selects.

  Image addresses:
    sau2  0x00E1CA62  kbd_$get_mode (module-local)
    sau6  0x7801E952  kbd_$get_mode (module-local)
    sau7  0x3C420C3E  kbd_$get_mode (module-local)

  - The result is the key's index in kbd_$mode_table, 0 when the key is
    not there.

  Status stored: none.
}

{ TODO(pascal) 4 unaddressed frame bytes (stand-in unused_a)

  The frame holds the reserved slot, i's slot and the word result
  variable's, and 4 more bytes that nothing addresses (12 untouched
  bytes, as in other `dbf' loops; with the reserved slot 4 of them are
  left).  What the source declared there is not known; the stand-in
  unused_a (2 bytes, the result's slot then below it, rounded) holds the
  place. }

function kbd_$get_mode(ch: char): integer; internal;
var
  i: integer;
  unused_a: integer;                      { the stand-in (TODO) }
begin
  { the mode keys }
  for i := 0 to 7 do
    if kbd_$mode_table[i] = ch then begin
      kbd_$get_mode := i;
      return;
    end;

  kbd_$get_mode := 0;
end;
