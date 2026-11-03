{ COLOR5_$INSTALL_DISP_MEM - make the display memory a canned object.

  Image addresses:
    sau8  0x03C38DAE  COLOR5_$INSTALL_DISP_MEM

  - The display's UID, its memory's address and 128 KB, touched
    (OS_$INSTALL_DISPLAY_ASTE).

  Status stored:
    status_$ok: always
}

[section(os_init_proc, os_init_data)]
procedure color5_$install_disp_mem(dcte: color5_$dcte_ptr_t;
                                   out status: status_$t);
  options(val_param);
begin
  with dcte^.info^ do
    os_$install_display_aste(display_uid, memory, color5_$memory_size,
                             true);
  status.all := status_$ok;
end;
