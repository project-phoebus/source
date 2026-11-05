{ PEB_$PROC_CLEANUP - the board's part of a process's end.

  Image addresses:
    sau2  0x00E752BC  PEB_$PROC_CLEANUP
    sau6  0x78083938  PEB_$PROC_CLEANUP
    sau7  0x3C48BB34  PEB_$PROC_CLEANUP
    sau9  0x3C47CE90  PEB_$PROC_CLEANUP

  - When the board is installed and its pages are not,
    peb_$cleanup_internal takes the board.
  - Without `peb_board' (base/config.ins.pas) an empty procedure.

  Status stored: none.
}

{ TODO(pascal) PEB_$PROC_CLEANUP's frame

  The SAU2 frame has eight bytes, none addressed: the `with' temporary
  explains four; a global routine reserves no slot.  The other four are not
  explained (the plain `or''s value is formed in a register, no temporary).
  }

[section(proc2_delete_pro, proc2_delete_dat)]
procedure peb_$proc_cleanup;
begin
%if peb_board %then
  with peb_$info do
    if (not installed) or mmu_installed then
      return;
  peb_$cleanup_internal;
%endif
end;
