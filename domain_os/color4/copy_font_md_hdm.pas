{ COLOR4_$COPY_FONT_MD_HDM - copy the fonts to hidden display memory.

  Image addresses:
    sau7  0x3C48BB38  COLOR4_$COPY_FONT_MD_HDM
    sau8  0x03C7FE54  COLOR4_$COPY_FONT_MD_HDM

  - The CSR pages and the display memory are mapped into the kernel's
    address space (MMU_$INSTALL, under the unit's spin lock), and the
    PROM's font reloaded (RELOAD_FONT).
  - The 39 lines of 14 words after the font pointer go to the hidden
    display memory at line 984, word 50.
  - The result is 0.

  Status stored: none.
}

[section(color4_wired_proc, wired_data)]
function color4_$copy_font_md_hdm(dcte: color4_$dcte_ptr_t;
                                  var font: color4_$font_area_t;
                                  out status: status_$t): integer;
  options(val_param);
var
  info: color4_$info_ptr_t;
  token: pinteger;
  ppn: integer32;
  memory: integer32;
  i: integer;
  src: color4_$font_lines_ptr_t;
  pos: smd_$pos_t;
  row: integer;
  col: integer;
begin
  info := dcte^.info;
  token := ml_$spin_lock(info^.lock);
  ppn := info^.csr_ppn;
  memory := info^.memory;
  mmu_$install(ppn, info^.regs, 0, color4_$kernel_prot);
  mmu_$install(ppn + 1, univ_ptr(integer32(info^.regs) + color4_$page_size),
               0, color4_$kernel_prot);
  ppn := vtop_or_crash(info^.memory);
  for i := 0 to color4_$memory_pages - 1 do
    mmu_$install(ppn + i, univ_ptr(memory + i * color4_$page_size), 0,
                 color4_$kernel_prot);
  ml_$spin_unlock(info^.lock, token);
  reload_font;

  src := addr(font.lines);
  with info^.regs^ do begin
    pos.line := color4_$font_line;
    pos.column := color4_$font_word;
    reg_406 := 16#05;
    reg_400 := 16#E0;
    mask := 0;
    reg_404 := 16#CE;
    ctl.flag_14 := false;
    ctl.flag_12 := false;
    ctl.flag_15 := true;
    ctl.flag_11 := true;
    ctl.flag_9 := true;
    for row := 0 to color4_$font_lines - 1 do
      for col := 0 to color4_$font_words - 1 do
        color4_$memory_ptr_t(info^.memory)^[pos.line + row,
                                            pos.column + col] :=
          src^[row, col];
    reg_404 := 16#C0;
    reg_406 := 16#04;
  end;
  color4_$copy_font_md_hdm := 0;
end;
