{ KBD_$PUT - write to a keyboard line.

  Image addresses:
    sau2  0x00E1CEAC  KBD_$PUT
    sau3  0x00E1C04C  KBD_$PUT

  - kbd_$put_line, an empty procedure on the SAU2, does the writing.
  - Without `display_driver' there is no keyboard: the call is refused.

  Status stored:
    kbd_$get_desc's status: with `display_driver'
    status_$util_bus_undefined_interrupt: without it
}

{ TODO(pascal) 8 unaddressed frame bytes (stand-ins unused_8, unused_c)

  The frame holds kbd's slot and 8 more bytes that nothing addresses.
  What the source declared there is not known; the stand-ins unused_8
  and unused_c hold the place (the 4 bytes over of the TTY_$K_ routines,
  tty/k_flush_input.pas, are 8 here).  Two longwords, not one 8-byte array:
  the bytes do not start at a multiple of 8 from A6, where an object of
  8 bytes or more is placed, so the original's objects there were
  smaller. }

procedure kbd_$put(in line: pinteger; in type_arg: integer;
                   in str: univ kbd_$chars_t; in length: integer;
                   out status: status_$t);
%if display_driver %then
var
  kbd: kbd_$desc_ptr_t;
  unused_8: integer32;                    { the stand-ins (TODO) }
  unused_c: integer32;
begin
  kbd := kbd_$get_desc(line, status);
  if status.all <> status_$ok then
    return;
  kbd_$put_line(kbd^, type_arg, str, length);
end;
%else
begin
  status.all := status_$util_bus_undefined_interrupt;
end;
%endif
