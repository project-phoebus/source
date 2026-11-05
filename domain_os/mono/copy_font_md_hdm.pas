{ MONO_$COPY_FONT_MD_HDM - copy the fonts to hidden display memory.

  Image addresses:
    sau7  0x3C48D530  MONO_$COPY_FONT_MD_HDM
    sau8  0x03C80C40  MONO_$COPY_FONT_MD_HDM

  - The CSR pages and the display memory, line_bits * word_74 bits of
    it, are mapped into the kernel's address space (MMU_$INSTALL, under
    the unit's spin lock), and the PROM's font reloaded (RELOAD_FONT).
  - The 39 lines of 14 words after the font pointer go to the hidden
    display memory: at line 1, word 80 on the big form, at line 984, word
    50 on the small one.
  - The result is 0.

  Status stored: none.
}

[section(mono_wired_proc, wired_data)]
function mono_$copy_font_md_hdm(dcte: mono_$dcte_ptr_t;
                                var font: mono_$font_area_t;
                                out status: status_$t): integer;
  options(val_param);
var
  dst: integer32;
  hdm: mono_$hdm_ptr_t;
  info: mono_$info_ptr_t;
  token: pinteger;
  memory: integer32;
  bytes_per_line: integer;
  ppn: integer32;
  i: integer;
  src: mono_$font_lines_ptr_t;
  pos: smd_$pos_t;
  row: integer;
  col: integer;
begin
  info := dcte^.info;
  hdm := dcte^.hdm;
  token := ml_$spin_lock(info^.lock);
  memory := info^.memory;
  bytes_per_line := hdm^.line_bits div 8;
  ppn := info^.csr_ppn;
  mmu_$install(ppn, info^.regs, 0, mono_$kernel_prot);
  mmu_$install(ppn + 1, univ_ptr(integer32(info^.regs) + mono_$page_size),
               0, mono_$kernel_prot);
  ppn := vtop_or_crash(info^.memory);
  for i := 0 to rshft(bytes_per_line * hdm^.word_74, 10) - 1 do
    mmu_$install(ppn + i, univ_ptr(memory + i * mono_$page_size), 0,
                 mono_$kernel_prot);
  ml_$spin_unlock(info^.lock, token);
  reload_font;

  src := addr(font.lines);
  with info^.regs^ do begin
    if hdm^.disp_type = mono_$big_display then begin
      pos.line := mono_$big_font_line;
      pos.column := mono_$big_font_word;
    end
    else begin
      pos.line := mono_$small_font_line;
      pos.column := mono_$small_font_word;
    end;
    reg_406 := 16#05;
    reg_400 := 16#E0;
    mask := 0;
    reg_404.mode := 3;
    ctl.flag_14 := false;
    ctl.flag_12 := false;
    ctl.flag_11 := true;
    ctl.flag_9 := true;
    dst := info^.memory;
    dst := pos.line * bytes_per_line + dst + pos.column * 2;
    for row := 0 to mono_$font_lines - 1 do begin
      for col := 0 to mono_$font_words - 1 do
        mono_$line_ptr_t(dst)^[col] := src^[row, col];
      dst := dst + bytes_per_line;
    end;
    reg_406 := 16#04;
  end;
  mono_$copy_font_md_hdm := 0;
end;
