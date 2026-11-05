{ COLOR6_$UNMAP_DISP - unmap the display memory.

  Image addresses:
    sau7  0x3C4838B0  COLOR6_$UNMAP_DISP

  Status stored:
    MST_$UNMAP's status: the memory was unmapped, or could not be
}

procedure color6_$unmap_disp(dcte: color6_$dcte_ptr_t;
                             arg_2: integer32; arg_3: integer32;
                             va: integer32; out status: status_$t);
  options(val_param);
begin
  mst_$unmap(color6_display_uid, va, color6_$memory_size, status);
end;
