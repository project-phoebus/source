{ dtty_$color_command - send a command to the color graphics board.

  Image addresses:
    sau4  0x0F81E7CA  dtty_$color_command (module-local)

  - After the board is idle, its mode word goes back to it (low byte all
    ones, after 16#F803), then the command's words one at a time.
  - With `dtty_color_board' only.

  Status stored: none.
}

procedure dtty_$color_command(in words: univ dtty_color_words_t;
                              count: integer); internal;
var
  saved: dtty_color_mode_t;
  i: integer;
begin
  with color_sup do begin
    while 13 in status do { empty };
    while 15 in status do { empty };
    saved.all := mode;
    saved.low := true;
    data := 16#F803;
    while 15 in status do { empty };
    data := saved.all;
    for i := 1 to count do begin
      while 15 in status do { empty };
      data := words[i];
    end;
  end;
end;
