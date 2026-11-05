{ TERM_$INQ_DISCIPLINE - report a terminal line's discipline.

  Image addresses:
    sau2  0x00E1AC9E  TERM_$INQ_DISCIPLINE
    sau3  0x00E1A2F0  TERM_$INQ_DISCIPLINE
    sau4  0x0F81BEB2  TERM_$INQ_DISCIPLINE
    sau6  0x7801CBB6  TERM_$INQ_DISCIPLINE
    sau7  0x3C41EECA  TERM_$INQ_DISCIPLINE
    sau8  0x03C1C282  TERM_$INQ_DISCIPLINE
    sau9  0x3C41D81A  TERM_$INQ_DISCIPLINE

  - The real line's DTTE discipline, when the line maps.

  Status stored:
    term_$get_real_line's status: always
}

[section(wired_proc, wired_data)]
procedure term_$inq_discipline(in line: integer; out discipline: integer;
                               out status: status_$t);
var
  real_line: pinteger;
begin
  real_line := term_$get_real_line(line, status);
  if status.all = status_$ok then
    discipline := dtte[real_line].discipline;
end;
