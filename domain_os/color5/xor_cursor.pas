{ COLOR5_$XOR_CURSOR - draw or remove the cursor.

  Image addresses:
    sau7  0x3C48C3E2  COLOR5_$XOR_CURSOR
    sau8  0x03C806FE  COLOR5_$XOR_CURSOR

  Assume we're called without the SMD request lock; it is held here.

  - What an earlier draw saved is copied back first (the unit's saved
    place and size; nothing when the saved height is 0).
  - Drawing (restore false): the cursor's pattern (SMD_$CURSOR_TABLE) is
    placed at pos less its hot spot, kept inside limits; what it covers
    is copied by the board to the hidden save area and noted in the
    unit's state, then the pattern is written over it, one word or two
    per line by where it falls.
  - With flag 10 of the control word set nothing is drawn, the board is
    given command 16#0B and the result is false; otherwise true.

  Status stored: none.
}

[section(color5_wired_proc, wired_data)]
function color5_$xor_cursor(dcte: color5_$dcte_ptr_t; cursor_num: pinteger;
                            pos: smd_$pos_t;
                            in limits: smd_$window_limits_t;
                            restore: boolean): boolean;
  options(val_param);
var
  info: color5_$info_ptr_t;
  board: color5_$regs_ptr_t;
  disp: color5_$memory_ptr_t;
  p: smd_$pos_t;
  mask: color5_$mask_t;
  rot: color5_$mask_t;
  inv: integer32;
  from_word: integer;
  from_line: integer;
  to_word: integer;
  to_line: integer;
  shift: integer;
  saved_404: color5_$byte_t;
  saved_405: color5_$byte_t;
  busy: boolean;
  pat: color5_$cursor_pattern_ptr_t;
  k: integer;
begin
  info := dcte^.info;
  board := info^.regs;
  disp := color5_$memory_ptr_t(info^.memory);
  proc1_$set_lock(ml_$smd_request_lock);
  pat := addr(smd_$cursor_table[cursor_num]);

  { the pattern's place, inside the limits }
  p.column := pos.column - pat^.hot_x;
  if p.column < 0 then
    p.column := 0;
  if limits.xe - pat^.size.width + 1 < p.column then
    p.column := limits.xe - pat^.size.width + 1;
  p.line := pos.line + pat^.hot_y_adj - pat^.size.height + 1;
  if p.line < 0 then
    p.line := 0;
  if limits.ye - pat^.size.height + 1 < p.line then
    p.line := limits.ye - pat^.size.height + 1;

  busy := board^.ctl.flag_10;
  if busy then begin
    board^.reg_406 := 16#0B;
    color5_$xor_cursor := false;
  end
  else begin
    color5_$xor_cursor := true;
    board^.ctl.flag_14 := false;
    board^.ctl.flag_12 := false;
    saved_404 := board^.reg_404;
    saved_405 := board^.reg_405;
    board^.reg_404 := 0;
    board^.reg_405 := 16#C0;
    board^.ctl.flag_15 := true;
    board^.ctl.flag_11 := true;
    board^.ctl.flag_9 := true;

    { what is saved, copied back by the board: each line's two words
      are given their destination's word address }
    if info^.saved_size.height > 0 then begin
      board^.reg_400 := 16#80;
      board^.reg_406 := 16#0E;
      to_word := info^.saved_column div 16;
      to_line := info^.saved_line - 1;
      for k := 1 to info^.saved_size.height do begin
        board^.mask := 0;
        disp^[color5_$save_line - 1 + k, color5_$save_word] :=
          (to_line + k) * color5_$line_words + to_word;
        board^.mask := 0;
        disp^[color5_$save_line - 1 + k, color5_$save_word + 1] :=
          (to_line + k) * color5_$line_words + to_word + 1;
      end;
      info^.saved_size.height := 0;
    end;

    if not restore then
      with info^ do begin
        { what the cursor covers, saved and noted }
        saved_size := pat^.size;
        saved_column := p.column;
        saved_line := p.line;
        board^.reg_400 := 16#80;
        board^.reg_406 := 16#0E;
        from_word := saved_column div 16;
        to_word := from_word;
        from_line := saved_line - 1;
        for k := 1 to saved_size.height do begin
          board^.mask := 0;
          disp^[from_line + k, to_word] :=
            (color5_$save_line - 1 + k) * color5_$line_words +
            color5_$save_word;
          board^.mask := 0;
          disp^[from_line + k, to_word + 1] :=
            (color5_$save_line - 1 + k) * color5_$line_words +
            color5_$save_word + 1;
        end;
        board^.reg_406 := 16#0F;

        { the pattern, shifted to its pixel, through the mask }
        board^.word_002 := 16#4447;
        board^.word_004 := 16#4444;
        board^.reg_400 := 16#E0;
        board^.reg_406 := 16#09;
        shift := saved_column & 15;
        mask.all := rshft(lshft(16#FFFF0000, 16 - saved_size.width), shift);
        board^.reg_400 := board^.reg_400 ! shift;
        if mask.lo = 0 then begin
          { one word a line }
          mask.all := ~(lshft(mask.all, 16) ! rshft(mask.all, 16));
          for k := 1 to saved_size.height do begin
            board^.mask := mask.lo;
            disp^[from_line + k, from_word] := pat^.bitmap[k];
          end;
        end
        else begin
          { two words a line }
          inv := ~mask.all;
          rot.all := lshft(inv, 16) ! rshft(inv, 16);
          for k := 1 to saved_size.height do begin
            board^.mask := rot.lo;
            disp^[from_line + k, from_word] := pat^.bitmap[k];
            board^.mask := inv;
            disp^[from_line + k, from_word + 1] := 0;
          end;
        end;
      end;
    board^.reg_400 := 16#E0;
    board^.reg_404 := saved_404;
    board^.reg_405 := saved_405;
    board^.mask := 0;
    board^.ctl.flag_14 := false;
    board^.ctl.flag_13 := false;
    board^.ctl.flag_12 := false;
  end;
  proc1_$clr_lock(ml_$smd_request_lock);
end;
