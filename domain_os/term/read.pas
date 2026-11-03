{ TERM_$READ - read characters from a terminal line.

  Image addresses:
    sau2  0x00E6681C  TERM_$READ
    sau3  0x00E67786  TERM_$READ
    sau4  0x0F870310  TERM_$READ

  - TTY_$K_GET on the real line, conditionally when its DTTE flag is
    set; the result is the count read.
  - On the early return the result is not assigned.

  Status stored:
    tty_$k_get's status, converted: the line was mapped
    term_$get_real_line's status: it was not
}

function term_$read(in line: integer; out buffer: univ term_$chars_t;
                    in count: pinteger; out status: status_$t): pinteger;
var
  real_line: pinteger;
begin
  real_line := term_$get_real_line(line, status);
  if status.all <> status_$ok then
    return;

  if dtte[real_line].flags then
    term_$read := tty_$k_get(line, [0], buffer, count, status)
  else
    term_$read := tty_$k_get(line, [], buffer, count, status);

  term_$status_convert(status);
end;
