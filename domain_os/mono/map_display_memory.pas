{ MONO_$MAP_DISPLAY_MEMORY - map the display memory into the current
  address space.

  Image addresses:
    sau7  0x3C4843FE  MONO_$MAP_DISPLAY_MEMORY
    sau8  0x03C79CAA  MONO_$MAP_DISPLAY_MEMORY

  - All of the display's object from its start, line_bits * word_74
    bits, whatever the driver passes in the second and third arguments
    (MST_$MAP).

  Status stored:
    MST_$MAP's status: the memory was mapped, or could not be
}

procedure mono_$map_display_memory(dcte: mono_$dcte_ptr_t;
                                   arg_2: integer32; arg_3: integer32;
                                   out va: univ_ptr;
                                   out status: status_$t);
  options(val_param);
var
  size: integer32;
  hdm: mono_$hdm_ptr_t;
  info: mono_$info_ptr_t;
  map_info: integer32;
begin
  hdm := dcte^.hdm;
  size := rshft(hdm^.line_bits * hdm^.word_74, 3);
  info := dcte^.info;
  va := mst_$map(info^.display_uid, 0, size, 6, 0, false, map_info,
                 status);
end;
