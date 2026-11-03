{ TTY_$I_GET_DESC - the TTY descriptor of a terminal line.

  Image addresses:
    sau2  0x00E66738  TTY_$I_GET_DESC
    sau3  0x00E676AC  TTY_$I_GET_DESC

  - For real line 0, the console, the discipline is set to
    term_$disc_enable_alt when the display TTY is not in use, and the
    display unblanked (with `display_driver').
  - A fragment of the OS_TERM module (term/os_term.pas), not of TTY.
  - On the two error exits the result is not assigned.

  Status stored:
    term_$get_real_line's status: the line was mapped, or not
    status_$requested_line_or_operation_not_implemented: the real line's
      DTTE entry has no descriptor
}

function tty_$i_get_desc(line: integer; out status: status_$t):
  integer32; options(val_param, a0_return);
var
  local_status: status_$t;
  real_line: pinteger;
begin
  real_line := term_$get_real_line(line, status);
  if status.all <> status_$ok then
    return;

  { the line must have a descriptor }
  if dtte[real_line].handler_ptr = nil then begin
    status.all := status_$requested_line_or_operation_not_implemented;
    return;
  end;

  { the console }
  if real_line = 0 then begin
    if not dtty_$use_dtty
       and then (dtte[real_line].discipline <> term_$disc_enable_alt)
    then
      term_$set_discipline(line, term_$disc_enable_alt,
                           local_status);
%if display_driver %then
    smd_$unblank;
%endif
  end;

  tty_$i_get_desc := integer32(dtte[real_line].handler_ptr);
end;
