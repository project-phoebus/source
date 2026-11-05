{ COLOR4_$INSTALL_DISP_MEM - make the display memory a canned object.

  Image addresses:
    sau7  0x3C43EBC0  COLOR4_$INSTALL_DISP_MEM
    sau8  0x03C38AFC  COLOR4_$INSTALL_DISP_MEM

  - The display's UID, its memory's address and 128 KB, touched
    (OS_$INSTALL_DISPLAY_ASTE).

  Status stored:
    status_$ok: always
}

[section(os_init_proc, os_init_data)]
procedure color4_$install_disp_mem(dcte: color4_$dcte_ptr_t;
                                   out status: status_$t);
  options(val_param);
begin
  with dcte^.info^ do
    os_$install_display_aste(display_uid, memory, color4_$memory_size,
                             true);
  status.all := status_$ok;
end;
