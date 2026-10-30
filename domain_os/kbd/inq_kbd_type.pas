{ KBD_$INQ_KBD_TYPE - return a line's keyboard type string.

  Image addresses:
    sau2  0x00E72562  KBD_$INQ_KBD_TYPE

  Status stored:
    kbd_$get_desc's status: always; the string is returned only on
      success
}

[section(procedure$, data$)]
procedure kbd_$inq_kbd_type(in line: pinteger;
                            out type_buf: univ kbd_$type_str_t;
                            out type_len: pinteger; out status: status_$t);
var
  kbd: kbd_$desc_ptr_t;
  i: integer;
begin
  kbd := kbd_$get_desc(line, status);
  if status.all <> status_$ok then
    return;

  for i := 0 to kbd^.kbd_type_len - 1 do
    type_buf[i] := kbd^.kbd_type_str[i];

  type_len := kbd^.kbd_type_len;
end;
