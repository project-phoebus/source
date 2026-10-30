{ PEB_$INIT - set the floating-point hardware up at boot.

  Image addresses:
    sau2  0x00E31D0C  PEB_$INIT
    sau5  0x00E33264  PEB_$INIT
    sau9  0x3C437E10  PEB_$INIT

  - With an MC68881 (M68881_EXISTS) the 68881's context is marked for
    saving and FIM_$FLINE installed at the line-F vector.
  - Otherwise the board's control page is mapped and probed: an answer
    installs PEB_$INT at PEB_VEC, marks the board installed and maps the
    WCS page; none removes the control page's mapping again.
  - Without `peb_board' (base/config.ins.pas) there is no board to
    probe, and the eventcount is not set up.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure peb_$init;
var
  probe_data: integer32;
  i: integer;
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
%else
  if m68881_exists then begin
    peb_$info.m68881_save_flag := true;
    trap_page[11] := addr(fim_$fline);
  end;
%endif
end;
