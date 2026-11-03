{ MONO_$UNMAP_DISPLAY_MEMORY - unmap the display memory.

  Image addresses:
    sau8  0x03C79D04  MONO_$UNMAP_DISPLAY_MEMORY

  - The display memory's size (line_bits * word_74 bits) at va
    (MST_$UNMAP); the second and third arguments are not read.

  Status stored:
    MST_$UNMAP's status: always
}

procedure mono_$unmap_display_memory(dcte: mono_$dcte_ptr_t;
                                     arg_2: integer32; arg_3: integer32;
                                     va: integer32;
                                     out status: status_$t);
  options(val_param);
var
  hdm: mono_$hdm_ptr_t;
  size: integer32;
  info: mono_$info_ptr_t;
begin
  hdm := dcte^.hdm;
  size := rshft(hdm^.line_bits * hdm^.word_74, 3);
  info := dcte^.info;
  mst_$unmap(info^.display_uid, va, size, status);
end;
