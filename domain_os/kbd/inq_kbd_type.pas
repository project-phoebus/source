{ KBD_$INQ_KBD_TYPE - return a line's keyboard type string.

  Image addresses:
    sau2  0x00E72562  KBD_$INQ_KBD_TYPE
    sau3  0x00E73B98  KBD_$INQ_KBD_TYPE

  - Without `display_driver' there is no keyboard: the call is refused.

  Status stored:
    kbd_$get_desc's status: with `display_driver'; the string is returned only on
      success
    status_$util_bus_undefined_interrupt: without `display_driver'
}

[section(procedure$, data$)]
procedure kbd_$inq_kbd_type(in line: pinteger;
                            out type_buf: univ kbd_$type_str_t;
                            out type_len: pinteger; out status: status_$t);
%if display_driver %then
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
%else
begin
  status.all := status_$util_bus_undefined_interrupt;
end;
%endif
