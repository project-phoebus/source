{ COLOR_$LOAD_CRSR - load a cursor into the color board's memory.

  Image addresses:
    sau4  0x0F87B412  COLOR_$LOAD_CRSR
    sau5  0x00E72FF2  COLOR_$LOAD_CRSR

  - Only when the board is ready and takes a cursor: size rows of size
    div 16 words go to word column 2 * cursor_num + 2, after the queue is
    drained (its status not read).
  - hot_x and hot_y_adj are not read.

  Status stored: none.
}

procedure color_$load_crsr(in cursor_num: integer; in size: integer;
                           in hot_x: integer; in hot_y_adj: integer;
                           in bitmap: univ color_$cursor_words_t);
var
  column: integer;
  rows: integer;
  words: integer;
  row: integer;
  i: integer;
  n: integer;
  line: integer;
  wait_status: status_$t;
begin
  column := cursor_num;
  rows := size;
  if not (12 in color_sup.status) then
    return;
  if 2 in color_sup.config then
    if (color_sup.field_80 & 16#F0) <> 16#F0 then
      return;
  color_$inq_done_wait(wait_status);
  color_sup.field_90 := 1;
  column := column * 2 + 2;
  n := 1;
  line := 0;
  words := rows div 16 - 1;
  for row := 1 to rows do begin
    for i := 0 to words do begin
      disp2_mem[line + column + i] := bitmap[n];
      n := n + 1;
    end;
    line := line + 16#40;
  end;
end;
