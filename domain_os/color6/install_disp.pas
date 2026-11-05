{ COLOR6_$INSTALL_DISP - make the display memory a canned object.

  Image addresses:
    sau7  0x3C43E96C  COLOR6_$INSTALL_DISP

  - The first call only: the board's display UID, the unit's memory
    address and 2 MB, not touched (OS_$INSTALL_DISPLAY_ASTE).

  Status stored:
    status_$ok: always
}

[section(os_init_proc, os_init_data)]
procedure color6_$install_disp(dcte: color6_$dcte_ptr_t;
                               out status: status_$t);
  options(val_param);
var
  first: static boolean := true;           { +0x6 }
begin
  if first then
    os_$install_display_aste(color6_display_uid, dcte^.info^.memory,
                             color6_$memory_size, false);
  status.all := status_$ok;
  first := false;
end;
