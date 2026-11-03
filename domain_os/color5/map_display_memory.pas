{ COLOR5_$MAP_DISPLAY_MEMORY - map the display memory into the current
  address space.

  Image addresses:
    sau8  0x03C7996A  COLOR5_$MAP_DISPLAY_MEMORY

  - All 128 KB of the display's object from its start, whatever the
    driver passes in the second and third arguments (MST_$MAP).

  Status stored:
    MST_$MAP's status: the memory was mapped, or could not be
}

procedure color5_$map_display_memory(dcte: color5_$dcte_ptr_t;
                                     arg_2: integer32; arg_3: integer32;
                                     out va: univ_ptr;
                                     out status: status_$t);
  options(val_param);
var
  map_info: integer32;
begin
  with dcte^.info^ do
    va := mst_$map(display_uid, 0, color5_$memory_size, 6, 0, false,
                   map_info, status);
end;
