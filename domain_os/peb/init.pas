{ PEB_$INIT - set the floating-point hardware up at boot.

  Image addresses:
    sau2  0x00E31D0C  PEB_$INIT
    sau5  0x00E33264  PEB_$INIT
    sau6  0x7803AAF4  PEB_$INIT
    sau7  0x3C43A970  PEB_$INIT
    sau9  0x3C437E10  PEB_$INIT

  - With an MC68881 (M68881_EXISTS) the 68881's context is marked for
    saving and FIM_$FLINE installed at the line-F vector.
  - Otherwise the board's control page is mapped and probed: an answer
    installs PEB_$INT at PEB_VEC, marks the board installed and maps the
    WCS page; none removes the control page's mapping again.
  - Without `peb_board' (base/config.ins.pas) there is no board to
    probe, and the eventcount is not set up.
  - With `peb_fpx' an FPX (FPX_EXISTS) comes first: it asks for the FP
    save area (savep_flag), an MC68881 marks its context, and either
    gets FIM_$FLINE.
  - With `fpa_board', when FPX_EXISTS is set the floating-point
    accelerator is probed at its control and status register, the
    answer kept in PEB_$INFO's flag_1d; an MC68881 then as without the
    board.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure peb_$init;
var
%if fpa_board %then
  probe_word: integer;
%endif
  probe_data: integer32;
%if not fpa_board %then
  i: integer;
%endif
%if peb_board %then
  j: integer32;
%endif
begin
%if peb_board %then
  ec_$init(peb_$info.eventcount);

  if m68881_exists then begin
    { the 68881's context is saved }
    peb_$info.m68881_save_flag := true;
    trap_page[11] := addr(fim_$fline);
  end
  else begin
    { every address space's board state }
    for i := 0 to 57 do
      for j := 1 to 7 do
        peb_$regs[i].longs[j] := 0;

    { the control page, then the probe }
    mmu_$install(16#2C, addr(peb_$m_ctrl_page), 0, 16#16);
    if not testpage(1, addr(peb_ctl), probe_data) then
      mmu_$remove(16#2C)
    else begin
      peb_vec := addr(peb_$int);
      peb_$info.installed := true;
      mmu_$install(16#2E, addr(peb_$m_cs_page), 0, 16#16);
      peb_ctl.ctl.all := 0;
    end;
  end;
%elseif peb_fpx %then
  if fpx_exists or m68881_exists then begin
    if fpx_exists then
      peb_$info.savep_flag := true
    else if m68881_exists then
      peb_$info.m68881_save_flag := true;
    trap_page[11] := addr(fim_$fline);
  end;
%elseif fpa_board %then
  if fpx_exists then
    peb_$info.flag_1d := testpage(1, univ_ptr(fpa_$csr_va), probe_word);
  if m68881_exists then begin
    peb_$info.m68881_save_flag := true;
    trap_page[11] := addr(fim_$fline);
  end;
%else
  if m68881_exists then begin
    peb_$info.m68881_save_flag := true;
    trap_page[11] := addr(fim_$fline);
  end;
%endif
end;
