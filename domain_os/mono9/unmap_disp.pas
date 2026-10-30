{ MONO9_$UNMAP_DISP - unmap the display memory.

  Image addresses:
    sau9  0x3C476E60  MONO9_$UNMAP_DISP

  - The 256 KB at va (MST_$UNMAP); the second and third arguments are
    not read.
  - MST_$UNMAP's status is replaced by status_$ok.

  Status stored:
    status_$ok: always
}

procedure mono9_$unmap_disp(dcte: mono9_$dcte_ptr_t; arg_2: integer32;
                            arg_3: integer32; va: integer32;
                            out status: status_$t);
  options(val_param);
begin
  with dcte^.info^ do
    mst_$unmap(display_uid, va, mono9_$memory_size, status);
  status.all := status_$ok;
end;
