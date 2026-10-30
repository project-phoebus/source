{ name_$parse_component - find the next component of a pathname.

  Image addresses:
    sau2  0x00E4A004  name_$parse_component

  - From start, '/' characters are skipped; the component's start and
    length up to the next '/' or the end are handed back, and next_pos
    the position after it.

  Status stored: none.
}

procedure name_$parse_component(in path: univ name_$long_pname_t;
                                path_len: pinteger; start: pinteger;
                                out next_pos: pinteger;
                                out comp_start: pinteger;
                                out comp_len: pinteger);
  internal;
begin
  { past the separators }
  comp_len := 0;
  next_pos := start;
  while (path_len >= next_pos) and then (path[next_pos] = '/') do
    next_pos := next_pos + 1;

  { the component }
  if next_pos <= path_len then begin
    comp_start := next_pos;
    while (path_len >= next_pos) and then (path[next_pos] <> '/') do begin
      next_pos := next_pos + 1;
      comp_len := comp_len + 1;
    end;
  end;
end;
