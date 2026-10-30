{ MONO9_$MAP_DISP - map the display memory into the current address
  space.

  Image addresses:
    sau9  0x3C476E14  MONO9_$MAP_DISP

  - All 256 KB of the display's object from its start, whatever the
    driver passes in the second and third arguments (MST_$MAP).

  Status stored:
    MST_$MAP's status: the memory was mapped, or could not be
}

procedure mono9_$map_disp(dcte: mono9_$dcte_ptr_t; arg_2: integer32;
                          arg_3: integer32; out va: univ_ptr;
                          out status: status_$t);
  options(val_param);
var
  map_info: integer32;
begin
  with dcte^.info^ do
    va := mst_$map(display_uid, 0, mono9_$memory_size, 6, 0, false,
                   map_info, status);
end;
