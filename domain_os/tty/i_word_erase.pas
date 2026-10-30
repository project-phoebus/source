{ tty_$i_word_erase - delete the last word of the input line.

  Image addresses:
    sau2  0x00E1B716  tty_$i_word_erase (module-local)

  - The separators at the end of the uncommitted input (BS, HT, LF, FF,
    CR and space, word_seps) are deleted first, then the characters
    back to the next separator, stopping at the committed input's end.
  - word_seps is this routine's static, WIRED_DATA +0x00, 32 bytes:
    member k is bit k mod 8 of byte (255 - k) div 8 (ref 3.9.3, Figure
    3-6).

  Status stored: none.
}

{ TODO(pascal) only the first loop gets the fields' addresses hoisted

  In the SAU2 image the first loop reaches tty.input.tail and
  tty.input_head through addresses formed before the loop, a hoisted
  loop invariant (ref 6.4.24 p. 6-29); the second loop, with the same
  references, reaches them through the descriptor's address.  Why only
  the first is not known; a `with' does not explain it (the two are word
  fields, and input_head is not in tty.input). }

[section(wired_proc, wired_data)]
procedure tty_$i_word_erase(var tty: tty_$desc_t); internal;
var
  { WIRED_DATA +0x00, 32 bytes }
  word_seps: static set of char :=
    [chr(8), chr(9), chr(10), chr(12), chr(13), ' '];
  prev: tty_$buf_pos_t;
begin
  { back over the separators }
  while tty.input.tail <> tty.input_head do begin
    if tty.input.tail = 1 then
      prev := tty_$buf_size
    else
      prev := tty.input.tail - 1;
    if not (tty.input.data[prev] in word_seps) then
      exit;
    tty_$i_delete_char(tty);
  end;

  { back over the word }
  while tty.input.tail <> tty.input_head do begin
    if tty.input.tail = 1 then
      prev := tty_$buf_size
    else
      prev := tty.input.tail - 1;
    if tty.input.data[prev] in word_seps then
      exit;
    tty_$i_delete_char(tty);
  end;
end;
