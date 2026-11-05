{ KBD_$SET_KBD_MODE - set a line's keyboard mode.

  Image addresses:
    sau2  0x00E72516  KBD_$SET_KBD_MODE
    sau3  0x00E73B74  KBD_$SET_KBD_MODE
    sau6  0x780809FA  KBD_$SET_KBD_MODE
    sau7  0x3C488B9A  KBD_$SET_KBD_MODE
    sau9  0x3C479F36  KBD_$SET_KBD_MODE

  - line and mode are not read but with `kbd_commands'.
  - With `kbd_commands' nothing is sent while the line's discipline is
    term_$disc_enable_alt; otherwise the keyboard gets the mode command
    for the mode's code (kbd_$send_mode).
  - Without `display_driver' there is no keyboard: the call is refused.

  Status stored:
    status_$ok: always but with `kbd_commands'; there, the discipline
      is term_$disc_enable_alt
    kbd_$get_desc's status: with `kbd_commands', otherwise
    status_$util_bus_undefined_interrupt: without `display_driver'
}

[section(procedure$, data$)]
procedure kbd_$set_kbd_mode(in line: pinteger; in mode: char;
                            out status: status_$t);
%if display_driver %then
var
  inq_status: status_$t;
  kbd: kbd_$desc_ptr_t;
  disc: integer;
begin
%if kbd_commands %then
  term_$inq_discipline(line, disc, inq_status);
  if disc = term_$disc_enable_alt then begin
    status.all := status_$ok;
    return;
  end;
  kbd := kbd_$get_desc(line, status);
  if status.all <> status_$ok then
    return;
  kbd_$send_mode(kbd^, kbd_$get_mode(mode));
%else
  status.all := status_$ok;
%endif
end;
%else
begin
  status.all := status_$util_bus_undefined_interrupt;
end;
%endif
