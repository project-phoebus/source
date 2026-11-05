{ COLOR7_$MAP_DISPLAY_MEMORY - give the display memory's address.

  Image addresses:
    sau7  0x3C4846F2  COLOR7_$MAP_DISPLAY_MEMORY

  - The memory is at its fixed address in every address space: nothing
    is mapped, and the second and third arguments are not read.

  Status stored:
    status_$ok: always
}

procedure color7_$map_display_memory(dcte: color7_$dcte_ptr_t;
                                     arg_2: integer32; arg_3: integer32;
                                     out va: univ_ptr;
                                     out status: status_$t);
  options(val_param);
begin
  va := univ_ptr(color7_$memory_va);
  status.all := status_$ok;
end;
