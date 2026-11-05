{ MONO_$XOR_CURSOR - draw or remove the cursor.

  Image addresses:
    sau7  0x3C48D7D2  MONO_$XOR_CURSOR
    sau7  0x3C48D70A  xor_at (nested)
    sau8  0x03C80EE2  MONO_$XOR_CURSOR
    sau8  0x03C80E1A  xor_at (nested)

  Assume we're called without the SMD request lock; it is held here.

  - The cursor's pattern (SMD_$CURSOR_TABLE) is placed at pos less its
    hot spot, kept inside limits, and exclusive-or'ed into the display
    memory there (xor_at), after it is taken off where the unit's state
    says it is drawn; removing (restore true) only takes it off.
  - With flag 10 of the control word set nothing is drawn, the board is
    given command 16#0B and the result is false; otherwise true.

  Status stored: none.
}

[section(mono_wired_proc, wired_data)]
function mono_$xor_cursor(dcte: mono_$dcte_ptr_t; cursor_num: pinteger;
                          pos: smd_$pos_t;
                          in limits: smd_$window_limits_t;
                          restore: boolean): boolean;
  options(val_param);
var
  info: mono_$info_ptr_t;
  regs: mono_$regs_ptr_t;
  p: smd_$pos_t;
  bytes_per_line: integer;
  t: integer;
  hdm: mono_$hdm_ptr_t;
  busy: boolean;
  saved_mode: 0..3;
  saved_flags: mono_$byte_t;
  saved_400: mono_$byte_t;

  { xor_at - exclusive-or the cursor's pattern into the display memory
    with its top left at column, line: two words a line, through the
    shifted mask.  Nested: it reads the parent's cursor number,
    registers, state and line length, and leaves the pattern's pixel
    shift in the parent's t. }
  procedure xor_at(column: integer; line: integer);
  var
    mask: integer32;
    pat: mono_$cursor_pattern_ptr_t;
    inv: integer32;
    rot: integer32;
    word: integer;
    dst: integer32;
    k: integer;
  begin
    pat := addr(smd_$cursor_table[cursor_num]);
    t := column & 15;
    mask := rshft(lshft(16#FFFF0000, 16 - pat^.width), t);
    regs^.reg_400 := regs^.reg_400 ! t;
    word := column div 16;
    inv := ~mask;
    rot := lshft(inv, 16) ! rshft(inv, 16);
    dst := info^.memory + line * bytes_per_line;
    for k := 1 to pat^.height do begin
      regs^.mask := rot;
      mono_$line_ptr_t(dst)^[word] := pat^.bitmap[k];
      regs^.mask := inv;
      mono_$line_ptr_t(dst)^[word + 1] := 0;
      dst := dst + bytes_per_line;
    end;
  end;

begin
  hdm := dcte^.hdm;
  info := dcte^.info;
  regs := info^.regs;
  proc1_$set_lock(ml_$smd_request_lock);
  with smd_$cursor_table[cursor_num] do begin
    { the pattern's place, inside the limits }
    p.column := pos.column - hot_x;
    if p.column < 0 then
      p.column := 0;
    t := limits.xe - width + 1;
    if t < p.column then
      p.column := t;
    p.line := pos.line + hot_y_adj - height + 1;
    if p.line < 0 then
      p.line := 0;
    if limits.ye - height + 1 < p.line then
      p.line := limits.ye - height + 1;
  end;

  busy := regs^.ctl.flag_10;
  if busy then begin
    regs^.reg_406 := 16#0B;
    mono_$xor_cursor := false;
  end
  else begin
    mono_$xor_cursor := true;
    saved_mode := regs^.reg_404.mode;
    saved_flags := regs^.ctl.flags;
    regs^.reg_406 := 16#05;
    saved_400 := regs^.reg_400;
    bytes_per_line := hdm^.line_bits div 8;
    regs^.reg_406 := 16#08;
    regs^.word_002 := 16#4446;
    regs^.reg_400 := 16#E0;
    regs^.reg_406 := 16#09;
    regs^.reg_404.mode := 3;
    if info^.drawn then
      xor_at(info^.drawn_column, info^.drawn_line);
    if not restore then
      xor_at(p.column, p.line);
    info^.drawn := not restore;
    info^.drawn_column := p.column;
    info^.drawn_line := p.line;
    regs^.reg_404.mode := saved_mode;
    regs^.ctl.flags := saved_flags;
    regs^.reg_400 := saved_400;
    regs^.mask := 0;
  end;
  proc1_$clr_lock(ml_$smd_request_lock);
end;
