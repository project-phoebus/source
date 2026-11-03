{ MONO_$INSTALL_DISP_MEM - make the display memory a canned object.

  Image addresses:
    sau8  0x03C38F76  MONO_$INSTALL_DISP_MEM

  - The display's UID, its memory's address and its size (line_bits *
    word_74 bits), touched (OS_$INSTALL_DISPLAY_ASTE).

  Status stored:
    status_$ok: always
}

[section(os_init_proc, os_init_data)]
procedure mono_$install_disp_mem(dcte: mono_$dcte_ptr_t;
                                 out status: status_$t);
  options(val_param);
var
  info: mono_$info_ptr_t;
  hdm: mono_$hdm_ptr_t;
begin
  info := dcte^.info;
  hdm := dcte^.hdm;
  os_$install_display_aste(info^.display_uid, info^.memory,
                           rshft(hdm^.line_bits * hdm^.word_74, 3), true);
  status.all := status_$ok;
end;
