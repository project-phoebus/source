{ KBD_$SET_KBD_TYPE - set a line's keyboard type string.

  Image addresses:
    sau2  0x00E72524  KBD_$SET_KBD_TYPE

  Status stored:
    kbd_$get_desc's status: always; the type is set only on success
}

{ TODO(pascal) 4 unaddressed frame bytes (stand-in unused_8)

  The frame holds kbd's slot and 4 more bytes that nothing addresses, as
  in the TTY_$K_ routines (tty/k_flush_input.pas, TODO there), though those
  push the line on by value and this one passes its slot on by address.
  The stand-in unused_8 holds the place. }

[section(procedure$, data$)]
procedure kbd_$set_kbd_type(in line: pinteger;
                            in type_str: univ kbd_$type_str_t;
                            in type_len: pinteger; out status: status_$t);
var
  kbd: kbd_$desc_ptr_t;
  unused_8: integer32;                    { the stand-in (TODO) }
begin
  kbd := kbd_$get_desc(line, status);
  if status.all <> status_$ok then
    return;
  kbd_$set_type(kbd^, type_str, type_len);
end;
