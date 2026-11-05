{ TERM_$READ_COND - read the characters a terminal line has, without
  waiting.

  Image addresses:
    sau2  0x00E6689A  TERM_$READ_COND
    sau3  0x00E67804  TERM_$READ_COND
    sau4  0x0F87038E  TERM_$READ_COND
    sau7  0x3C479F16  TERM_$READ_COND

  - TTY_$K_GET with the conditional option; the result is the count
    read.

  Status stored:
    tty_$k_get's status, converted: always
}

function term_$read_cond(in line: integer; out buffer: univ term_$chars_t;
                         in count: pinteger; out status: status_$t):
  pinteger;
begin
  term_$read_cond := tty_$k_get(line, [0], buffer, count, status);
  term_$status_convert(status);
end;
