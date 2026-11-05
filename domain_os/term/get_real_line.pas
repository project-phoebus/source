{ TERM_$GET_REAL_LINE - map a terminal line to the real line it stands for.

  Image addresses:
    sau2  0x00E1A9D4  TERM_$GET_REAL_LINE
    sau3  0x00E1A038  TERM_$GET_REAL_LINE
    sau4  0x0F81BBE8  TERM_$GET_REAL_LINE
    sau7  0x3C41EBC0  TERM_$GET_REAL_LINE

  - Line 0, and line 1 for process 1, become the display's control line;
    the result is the line, also on a refusal.  The compares are
    unsigned.

  Status stored:
    status_$ok: the line is good
    status_$invalid_line_number: a line above 3
    status_$requested_line_or_operation_not_implemented: a line at or
      above TERM_$MAX_DTTE, or without `display_driver' real line 0
}

[section(wired_proc, wired_data)]
function term_$get_real_line(line: integer; out status: status_$t):
  pinteger;
var
  real_line: pinteger;
begin
  status.all := status_$ok;
  real_line := line;

  { line 1 is the display for process 1, line 0 always }
  if real_line = 1 then begin
    if proc1_$current = 1 then
      real_line := dtty_$ctrl
    else
      real_line := 1;
  end
  else if real_line = 0 then
    real_line := dtty_$ctrl;

  if real_line > 3 then
    status.all := status_$invalid_line_number
%if display_driver %then
  else if real_line >= term_$max_dtte then
    status.all := status_$requested_line_or_operation_not_implemented;
%else
  else if (real_line >= term_$max_dtte) or else (real_line = 0) then
    status.all := status_$requested_line_or_operation_not_implemented;
%endif

  term_$get_real_line := real_line;
end;
