{ PEB_$DISSOC - give the board's command page up.

  Image addresses:
    sau2  0x00E5ADA4  PEB_$DISSOC

  - The command page's mapping is removed, the owner cleared and the
    pages marked not installed.

  Status stored: none.
}

procedure peb_$dissoc;
begin
  with peb_$info do begin
    mmu_$remove(16#2D);
    owner_pid := 0;
    mmu_installed := false;
  end;
end;
