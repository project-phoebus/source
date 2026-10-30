{ peb_$cleanup_internal - take the board from an ending process.

  Image addresses:
    sau2  0x00E70954  peb_$cleanup_internal

  - With interrupts off, a board the current process owns is waited for
    (10000 polls, then a crash: "fpu is hung"), its private page's
    mapping removed and the owner cleared.
  - The current address space's saved state is then cleared.

  Status stored: none.
}

procedure peb_$cleanup_internal; internal;
var
  i: integer;
  j: integer32;
begin
  with peb_$info do begin
    disable;
    if owner_pid = proc1_$current then begin
      { wait while the board is busy }
      if peb_ctl.ctl.all < 0 then begin
        for i := 1 to 10000 do
          if peb_ctl.ctl.all >= 0 then
            exit;
        if peb_ctl.ctl.all < 0 then begin
          enable;
          crash_system(peb_fpu_is_hung_err);
        end;
      end;

      mmu_$remove(16#2D);
      owner_pid := 0;
    end;
    enable;
  end;

  { the address space's saved state }
  for j := 1 to 7 do
    peb_$regs[proc1_$as_id].longs[j] := 0;
end;
