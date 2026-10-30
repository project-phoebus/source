{ PEB_$ASSOC - make the current process the board's owner.

  Image addresses:
    sau2  0x00E5AD38  PEB_$ASSOC

  - The current process and address space become the board's owner; the
    first time, the pages are marked installed and the board's WCS,
    control and command pages mapped (protection 6).

  Status stored: none.
}

procedure peb_$assoc;
begin
  with peb_$info do begin
    owner_pid := proc1_$current;
    owner_asid := proc1_$as_id;

    { the pages, once }
    if not mmu_installed then begin
      mmu_installed := true;
      mmu_$install(16#2E, addr(peb_$m_cs_page), 0, 6);
      mmu_$install(16#2C, addr(peb_$m_ctrl_page), 0, 6);
      mmu_$install(16#2D, addr(peb_$m_dcmd_page), 0, 6);
    end;
  end;
end;
