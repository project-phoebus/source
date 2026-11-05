{ COLOR4_$UNMAP_DISPLAY_MEMORY - unmap the display memory.

  Image addresses:
    sau7  0x3C483DD0  COLOR4_$UNMAP_DISPLAY_MEMORY
    sau8  0x03C7967C  COLOR4_$UNMAP_DISPLAY_MEMORY

  - The 128 KB at va (MST_$UNMAP); the second and third arguments are
    not read.

  Status stored:
    MST_$UNMAP's status: always
}

procedure color4_$unmap_display_memory(dcte: color4_$dcte_ptr_t;
                                       arg_2: integer32; arg_3: integer32;
                                       va: integer32;
                                       out status: status_$t);
  options(val_param);
begin
  with dcte^.info^ do
    mst_$unmap(display_uid, va, color4_$memory_size, status);
end;
