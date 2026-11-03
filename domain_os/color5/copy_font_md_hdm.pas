{ COLOR5_$COPY_FONT_MD_HDM - copy the fonts to hidden display memory.

  Image addresses:
    sau8  0x03C8054C  COLOR5_$COPY_FONT_MD_HDM

  - The CSR pages and the display memory are mapped into the kernel's
    address space (MMU_$INSTALL, under the unit's spin lock), and the
    PROM's font reloaded (RELOAD_FONT).
  - The 39 lines of 14 words after the font pointer go to the hidden
    display memory at line 984, word 50.
  - The result is 0.

  Status stored: none.
}

[section(color5_wired_proc, wired_data)]
function color5_$copy_font_md_hdm(dcte: color5_$dcte_ptr_t;
                                  var font: color5_$font_area_t;
                                  out status: status_$t): integer;
  options(val_param);
var
  info: color5_$info_ptr_t;
  token: pinteger;
  ppn: integer32;
  memory: integer32;
  i: integer;
  src: color5_$font_lines_ptr_t;
  pos: smd_$pos_t;
  row: integer;
  col: integer;
begin
  info := dcte^.info;
  token := ml_$spin_lock(info^.lock);
  memory := info^.memory;
  ppn := info^.csr_ppn;
  mmu_$install(ppn, info^.regs, 0, color5_$kernel_prot);
  mmu_$install(ppn + 1, univ_ptr(integer32(info^.regs) + color5_$page_size),
               0, color5_$kernel_prot);
  ppn := vtop_or_crash(info^.memory);
  for i := 0 to color5_$memory_pages - 1 do
    mmu_$install(ppn + i, univ_ptr(memory + i * color5_$page_size), 0,
                 color5_$kernel_prot);
  ml_$spin_unlock(info^.lock, token);
  reload_font;

  src := addr(font.lines);
  with info^.regs^ do begin
    pos.line := color5_$font_line;
    pos.column := color5_$font_word;
    reg_406 := 16#05;
    reg_400 := 16#E0;
    mask := 0;
    reg_404 := 16#FE;
    reg_405 := 16#C0;
    ctl.flag_14 := false;
    ctl.flag_12 := false;
    ctl.flag_15 := true;
    ctl.flag_11 := true;
    ctl.flag_9 := true;
    for row := 0 to color5_$font_lines - 1 do
      for col := 0 to color5_$font_words - 1 do
        color5_$memory_ptr_t(info^.memory)^[pos.line + row,
                                            col + pos.column] :=
          src^[row, col];
    reg_404 := 0;
    reg_406 := 16#04;
  end;
  color5_$copy_font_md_hdm := 0;
end;
