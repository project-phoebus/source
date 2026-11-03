{ TERM_$SET_REAL_LINE_DISCIPLINE - set a real line's discipline.

  Image addresses:
    sau2  0x00E1AB62  TERM_$SET_REAL_LINE_DISCIPLINE
    sau3  0x00E1A1CA  TERM_$SET_REAL_LINE_DISCIPLINE
    sau8  0x03C1C14C  TERM_$SET_REAL_LINE_DISCIPLINE
    sau9  0x3C41D6E4  TERM_$SET_REAL_LINE_DISCIPLINE

  - Under the TTY spin lock, disciplines 0 and 3 re-point the line's SIO
    descriptor (to the TTY's handlers, or to SUMA_$RCV); 1 and 2 set the
    keyboard handler (none, or TTY_$I_RCV).
  - Discipline 2 then reloads the display font and sends the keyboard
    string; without `display_driver' it is refused, the discipline
    recorded all the same.  The discipline is recorded in the DTTE, for
    any value.

  Status stored:
    status_$ok: the discipline was set
    status_$invalid_line_number: a line above 3, or without the
      descriptor its discipline needs
    status_$requested_line_or_operation_not_implemented: a line at or
      above TERM_$MAX_DTTE
    status_$term_invalid_option: discipline 2 without `display_driver'
}

[section(wired_proc, wired_data)]
procedure term_$set_real_line_discipline(in line: pinteger;
                                         in discipline: integer;
                                         out status: status_$t);
var
  l: pinteger;
  disc: integer;
  desc: univ_ptr;
  kbd: univ_ptr;
  token: integer;
begin
  if line > 3 then
    status.all := status_$invalid_line_number
  else if line >= term_$max_dtte then
    status.all := status_$requested_line_or_operation_not_implemented
  else begin
    status.all := status_$ok;
    l := line;
    disc := discipline;
    case disc of
      { the SIO descriptor's handlers }
      term_$disc_tty, term_$disc_suma:
        with dtte[l] do begin
          desc := tty_handler;
          if desc = nil then begin
            status.all := status_$invalid_line_number;
            return;
          end;
          token := ml_$spin_lock(tty_$spin_lock);
          if disc = term_$disc_tty then begin
            sio_$desc_ptr_t(desc)^.owner := handler_ptr;
            sio_$desc_ptr_t(desc)^.handlers.rcv_handler := term_$tty_handlers[1];
            sio_$desc_ptr_t(desc)^.handlers.drain_handler := term_$tty_handlers[2];
            sio_$desc_ptr_t(desc)^.handlers.dcd_handler := term_$tty_handlers[3];
            sio_$desc_ptr_t(desc)^.handlers.special_rcv := term_$tty_handlers[4];
          end
          else
            sio_$desc_ptr_t(desc)^.handlers.rcv_handler := addr(suma_$rcv);
          ml_$spin_unlock(tty_$spin_lock, token);
        end;

      { the keyboard's handler }
      term_$disc_disable_alt, term_$disc_enable_alt:
        with dtte[l] do begin
          kbd := alt_handler;
          if kbd = nil then begin
            status.all := status_$invalid_line_number;
            return;
          end;
          token := ml_$spin_lock(tty_$spin_lock);
          if disc = term_$disc_disable_alt then begin
            kbd_$desc_ptr_t(kbd)^.handler := nil;
            ml_$spin_unlock(tty_$spin_lock, token);
          end
          else begin
%if display_driver %then
            kbd_$desc_ptr_t(kbd)^.handler := kbd_$handler_t(term_$kbd_rcv);
            ml_$spin_unlock(tty_$spin_lock, token);
            dtty_$reload_font;
            term_$send_kbd_string(term_$kbd_string, 5);
%else
            { no keyboard to give the line to }
            ml_$spin_unlock(tty_$spin_lock, token);
            status.all := status_$term_invalid_option;
%endif
          end;
        end;
    end;

    dtte[l].discipline := disc;
  end;
end;
