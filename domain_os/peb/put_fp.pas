{ PEB_$PUT_FP - save the board's state for an address space.

  Image addresses:
    sau2  0x00E5AF12  PEB_$PUT_FP

  - PEB_$UNLOAD_REGS into the address space's element of PEB_$REGS.

  Status stored: none.
}

procedure peb_$put_fp(in asid: integer);
begin
  peb_$unload_regs(peb_$regs[asid]);
end;
