{ MONO9_$INSTALL_DISP - make the display memory a canned object.

  Image addresses:
    sau9  0x3C43B752  MONO9_$INSTALL_DISP

  - The display's UID, its memory's address and 256 KB, untouched
    (OS_$INSTALL_DISPLAY_ASTE).

  Status stored:
    status_$ok: always
}

[section(os_init_proc, os_init_data)]
procedure mono9_$install_disp(dcte: mono9_$dcte_ptr_t;
                              out status: status_$t);
  options(val_param);
begin
  with dcte^.info^ do
    os_$install_display_aste(display_uid, memory_addr, mono9_$memory_size,
                             false);
  status.all := status_$ok;
end;
