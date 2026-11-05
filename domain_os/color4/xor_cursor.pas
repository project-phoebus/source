{ COLOR4_$XOR_CURSOR - draw or remove the cursor.

  Image addresses:
    sau7  0x3C48BCE2  COLOR4_$XOR_CURSOR
    sau8  0x03C7FFFE  COLOR4_$XOR_CURSOR

  Assume we're called without the SMD request lock; it is held here.

  - The cursor's pattern (SMD_$CURSOR_TABLE) is placed at pos less its
    hot spot, kept inside limits.
  - Drawing (restore false): what the cursor covers is copied by the
    board to the hidden save area, then the pattern is written over it,
    one word or two per line by where it falls.  Removing (restore true):
    the save area is copied back.
  - With flag 10 of the control word set nothing is drawn, the board is
    given command 16#0B and the result is false; otherwise true.

  Status stored: none.
}

[section(color4_wired_proc, wired_data)]
function color4_$xor_cursor(dcte: color4_$dcte_ptr_t; cursor_num: pinteger;
                            pos: smd_$pos_t;
                            in limits: smd_$window_limits_t;
                            restore: boolean): boolean;
  options(val_param);
var
  info: color4_$info_ptr_t;
  regs: color4_$regs_ptr_t;
  memory: color4_$memory_ptr_t;
  src: smd_$pos_t;
  dst: smd_$pos_t;
  p: smd_$pos_t;
  copy_from: smd_$pos_t;
  draw_from: smd_$pos_t;
  to_line: integer;
  to_word: integer;
  shift: integer;
  mask: color4_$mask_t;
  rot: color4_$mask_t;
  inv: integer32;
  saved_404: color4_$byte_t;
  busy: boolean;
  k: integer;
begin
  info := dcte^.info;
  regs := info^.regs;
  memory := color4_$memory_ptr_t(info^.memory);
  proc1_$set_lock(ml_$smd_request_lock);
  with smd_$cursor_table[cursor_num] do begin
    { the pattern's place, inside the limits }
    p.column := pos.column - hot_x;
    if p.column < 0 then
      p.column := 0;
    if limits.xe - width + 1 < p.column then
      p.column := limits.xe - width + 1;
    p.line := pos.line + hot_y_adj - height + 1;
    if p.line < 0 then
      p.line := 0;
    if limits.ye - height + 1 < p.line then
      p.line := limits.ye - height + 1;

    busy := regs^.ctl.flag_10;
    if busy then begin
      regs^.reg_406 := 16#0B;
      color4_$xor_cursor := false;
    end
    else begin
      color4_$xor_cursor := true;
      regs^.ctl.flag_14 := false;
      regs^.ctl.flag_12 := false;
      saved_404 := regs^.reg_404;
      regs^.reg_404 := 16#C0;
      regs^.ctl.flag_15 := true;
      regs^.ctl.flag_11 := true;
      regs^.ctl.flag_9 := true;
      if restore then begin
        src.line := color4_$save_line;
        src.column := color4_$save_column;
        dst := p;
      end
      else begin
        src := p;
        dst.line := color4_$save_line;
        dst.column := color4_$save_column;
      end;

      { the board copies the area: each line's two words are given their
        destination's word address }
      regs^.reg_400 := 16#80;
      regs^.reg_406 := 16#0E;
      draw_from.column := src.column div 16;
      copy_from.column := draw_from.column;
      draw_from.line := src.line - 1;
      copy_from.line := draw_from.line;
      to_word := dst.column div 16;
      to_line := dst.line - 1;
      for k := 1 to height do begin
        regs^.mask := 0;
        memory^[copy_from.line + k, copy_from.column] :=
          (to_line + k) * color4_$line_words + to_word;
        regs^.mask := 0;
        memory^[copy_from.line + k, copy_from.column + 1] :=
          (to_line + k) * color4_$line_words + to_word + 1;
      end;
      regs^.reg_406 := 16#0F;

      { the pattern, shifted to its pixel, through the mask }
      if not restore then begin
        regs^.word_002 := 16#4447;
        regs^.word_004 := 16#4444;
        regs^.reg_400 := 16#E0;
        regs^.reg_406 := 16#09;
        shift := p.column & 15;
        mask.all := rshft(lshft(16#FFFF0000, 16 - width), shift);
        regs^.reg_400 := regs^.reg_400 ! shift;
        if mask.lo = 0 then begin
          { one word a line }
          mask.all := ~(lshft(mask.all, 16) ! rshft(mask.all, 16));
          for k := 1 to height do begin
            regs^.mask := mask.lo;
            memory^[draw_from.line + k, draw_from.column] := bitmap[k];
          end;
        end
        else begin
          { two words a line }
          inv := ~mask.all;
          rot.all := lshft(inv, 16) ! rshft(inv, 16);
          for k := 1 to height do begin
            regs^.mask := rot.lo;
            memory^[draw_from.line + k, draw_from.column] := bitmap[k];
            regs^.mask := inv;
            memory^[draw_from.line + k, draw_from.column + 1] := 0;
          end;
        end;
      end;
      regs^.reg_400 := 16#E0;
      regs^.reg_404 := saved_404;
      regs^.mask := 0;
      regs^.ctl.flag_14 := false;
      regs^.ctl.flag_13 := false;
      regs^.ctl.flag_12 := false;
    end;
  end;
  proc1_$clr_lock(ml_$smd_request_lock);
end;
