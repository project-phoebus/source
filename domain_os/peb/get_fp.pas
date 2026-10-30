{ PEB_$GET_FP - load the board with an address space's saved state.

  Image addresses:
    sau2  0x00E5AEEC  PEB_$GET_FP

  - PEB_$LOAD_REGS of the address space's element of PEB_$REGS.

  Status stored: none.
}

procedure peb_$get_fp(in asid: integer);
begin
  peb_$load_regs(peb_$regs[asid]);
end;
