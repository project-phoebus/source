{ PROC1_$SET_ASID - give the current process an address space.

  Image addresses:
    sau2  0x00E148F8  PROC1_$SET_ASID
    sau4  0x0F81516C  PROC1_$SET_ASID

  - MMU_$INSTALL_ASID also sets PROC1_$AS_ID.

  Status stored: none.
}

procedure proc1_$set_asid(asid: integer);
begin
  proc1_$current_pcb^.asid := asid;
  mmu_$install_asid(asid);
end;
