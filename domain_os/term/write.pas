{ TERM_$WRITE - write characters to a terminal line.

  Image addresses:
    sau2  0x00E668D8  TERM_$WRITE
    sau3  0x00E67842  TERM_$WRITE
    sau4  0x0F8703CC  TERM_$WRITE
    sau7  0x3C479F54  TERM_$WRITE

  - TTY_$K_PUT with no options.

  Status stored:
    tty_$k_put's status, converted: always
}

procedure term_$write(in line: integer; in buffer: univ term_$chars_t;
                      count: pinteger; out status: status_$t);
begin
  tty_$k_put(line, [], buffer, count, status);
  term_$status_convert(status);
end;
