{ TERM_$SET_DISCIPLINE - set a terminal line's discipline.

  Image addresses:
    sau2  0x00E1AB2A  TERM_$SET_DISCIPLINE
    sau3  0x00E1A192  TERM_$SET_DISCIPLINE
    sau9  0x3C41D6AC  TERM_$SET_DISCIPLINE

  - TERM_$SET_REAL_LINE_DISCIPLINE for the real line.

  Status stored:
    term_$set_real_line_discipline's status: the line was mapped
    term_$get_real_line's status: it was not
}

[section(wired_proc, wired_data)]
procedure term_$set_discipline(in line: integer; in discipline: integer;
                               out status: status_$t);
var
  real_line: pinteger;
begin
  real_line := term_$get_real_line(line, status);
  if status.all = status_$ok then
    term_$set_real_line_discipline(real_line, discipline, status);
end;
