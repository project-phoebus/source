{ COLOR6_$MAP_DISP - map the display memory into the current address
  space.

  Image addresses:
    sau7  0x3C483864  COLOR6_$MAP_DISP

  - The board's display memory object, 2 MB (MST_$MAP).

  Status stored:
    MST_$MAP's status: the memory was mapped, or could not be
}

procedure color6_$map_disp(dcte: color6_$dcte_ptr_t;
                           arg_2: integer32; arg_3: integer32;
                           out va: univ_ptr; out status: status_$t);
  options(val_param);
var
  map_info: integer32;
begin
  va := mst_$map(color6_display_uid, 0, color6_$memory_size, 6, 0, false,
                 map_info, status);
end;
