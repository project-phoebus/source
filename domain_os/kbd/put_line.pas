{ kbd_$put_line - KBD_$PUT's worker: write a string to a keyboard line.

  Image addresses:
    sau2  0x00E1CA8A  kbd_$put_line (module-local)
    sau6  0x7801EA10  kbd_$put_line (module-local)
    sau7  0x3C420CFC  kbd_$put_line (module-local)
    sau9  0x3C41F64C  kbd_$put_line (module-local)

  - An empty procedure but with `kbd_commands'; the parameters are its
    callers' pushes.
  - With `kbd_commands' the string goes into the console's transmit
    buffer until it is all taken, waiting on the line's eventcount
    while the buffer is full.
  - Each pass hands kbd_$txbuf_put the string from its first character,
    with the count still to send.  type_arg is not read.
  - A fragment of its own: on the SAU2 it lies between kbd_$get_mode and
    kbd_$set_type, far from KBD_$PUT (kbd/README.md).

  Status stored: none.
}

procedure kbd_$put_line(var kbd: kbd_$desc_t; type_arg: integer;
                        in str: univ kbd_$chars_t; length: integer);
  internal;
%if kbd_commands %then
var
  sent: integer;
  wait_val: integer32;
%endif
begin
%if kbd_commands %then
  sent := 0;
  repeat
    sent := sent + kbd_$txbuf_put(kbd, str, length - sent);
    if sent = length then
      exit;
    wait_val := kbd.ec.value;
    { full: the next producer position is the consumer's }
    if (kbd.txbuf.tail + 1 = kbd.txbuf.head)
       or else ((kbd.txbuf.tail = kbd_$ring_size)
                and then (kbd.txbuf.head = 1)) then
      discard(ec_$wait(addr(kbd.ec), addr(ec_$nil_ec), addr(ec_$nil_ec),
                       wait_val + 1, 0, 0));
  until false;
%endif
end;
