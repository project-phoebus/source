{ TERM_$SEND_KBD_STRING - put a string into the console keyboard's
  input.

  Image addresses:
    sau2  0x00E1AAFC  TERM_$SEND_KBD_STRING
    sau3  0x00E1A164  TERM_$SEND_KBD_STRING

  - KBD_$PUT for line 0 with type 0; the converted status is dropped.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure term_$send_kbd_string(in str: univ term_$chars_t; in len: integer);
var
  status: status_$t;
begin
  kbd_$put(0, 0, str, len, status);
  term_$status_convert(status);
end;
